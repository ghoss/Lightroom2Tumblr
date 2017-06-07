--[[----------------------------------------------------------------------------

Lightroom2Tumblr

TumblrAuthentication.lua - OAuth authentication procedures for Tumblr

Copyright (c) 2012-2017 by Guido Hoss.

Lightroom2Tumblr is free software: you can redistribute it and/or 
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public
License along with this program.  If not, see
<http://www.gnu.org/licenses/>.

Git repository home: <https://github.com/ghoss/Lightroom2Tumblr>

------------------------------------------------------------------------------]]


--------------------------------------------------------------------------------
-- INCLUDES, CONSTANTS
--------------------------------------------------------------------------------

local LrMD5             = import 'LrMD5'
local LrXml             = import 'LrXml'
local LrDate            = import 'LrDate'
local LrDialogs         = import 'LrDialogs'
local LrHttp            = import 'LrHttp'
local LrStringUtils     = import 'LrStringUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks		= import 'LrTasks'
local LrBinding		= import 'LrBinding'
local LrView		= import 'LrView'

require 'Info'
require 'LrSHA1'


--------------------------------------------------------------------------------
-- generate_nonce()
--------------------------------------------------------------------------------

local function generate_nonce()
	return LrMD5.digest(tostring(math.random()) .. tostring(LrDate.currentTime()))
end


--------------------------------------------------------------------------------
-- oauth_encode()
--
-- Like URL-encoding, but following OAuth's specific semantics
--------------------------------------------------------------------------------

function oauth_encode(val)

	-- The wrapping tostring() is to ensure that only one item is returned (it's easy to
	-- forget that gsub() returns multiple items
	return tostring(val:gsub('[^-._~a-zA-Z0-9]', 
		function(letter)
			return string.format("%%%02x", letter:byte()):upper()
		end)
	)
end


--------------------------------------------------------------------------------
-- unix_timestamp()
--
-- Returns the current time as a Unix timestamp.
--------------------------------------------------------------------------------

-- UnixTime of 978307200 is a CocoaTime of 0
local CocoTimeShift = 978307200

local function unix_timestamp()
	return tostring(CocoTimeShift + math.floor(LrDate.currentTime() + 0.5))
end


--------------------------------------------------------------------------------
-- oauth_sign()
--
-- Given a url endpoint, a GET/POST method, and a table of key/value args, build
-- the query string and sign it, returning the query string (in the case of a
-- POST) or, for a GET, the final url.
--
-- The args should also contain an 'oauth_token_secret' item, except for the
-- initial token request.
--------------------------------------------------------------------------------

local function sort_alphanum(a, b)
	if a.key < b.key then
		return true
	elseif a.key > b.key then
		return false
	else
		return a.val < b.val
	end
end


function oauth_sign( url, method, args )

	assert(method == 'GET' or method == 'POST')
	local token_secret = args.oauth_token_secret or ""

	-- Remove the token_secret from the args, 'cause we neither send nor sign it.
	-- (we use it for signing which is why we need it in the first place)
	--
	args.oauth_token_secret = nil

	-- Tumblr does only HMAC-SHA1
	-- These arguments are also the same for each request
	--
	args.oauth_signature_method = 'HMAC-SHA1'
	args.oauth_consumer_key = ConsumerKey()
	args.oauth_timestamp = unix_timestamp()
	args.oauth_version = '1.0'
	args.oauth_nonce = generate_nonce()

	-- oauth-encode each value, and get them set up for a Lua table sort.
	-- Don't encode the key! (Tumblr barks at encoded "data[..]" keys in photo submission request)
	--
	local keys_and_values = { }

	for key, val in pairs(args) do
		table.insert(keys_and_values,  {
			key = key,
			val = oauth_encode(val)
		})
	end

	-- Sort by key first, then value
	--
	table.sort(keys_and_values, sort_alphanum)

	-- Now combine key and value into key=value
	--
	local key_value_pairs = { }
	for _, rec in pairs(keys_and_values) do
		table.insert(key_value_pairs, rec.key .. "=" .. rec.val)
	end

	-- Now we have the query string we use for signing, and, after we add the
	-- signature, for the final as well.
	--
	local query_string_except_signature = table.concat(key_value_pairs, "&")

	-- Create Signature Base String
	local SignatureBaseString = method .. '&' .. oauth_encode(url) .. '&' .. 
		oauth_encode(query_string_except_signature)
	local key = oauth_encode(ConsumerSecret()) .. '&' .. oauth_encode(token_secret)

	-- Now have our text and key for HMAC-SHA1 signing
	--
	local hmac_binary = hmac_sha1_binary(key, SignatureBaseString)

	-- Base64 encode it
	--
	local hmac_b64 = LrStringUtils.encodeBase64(hmac_binary)

	-- Now create the signature
	--
	table.insert(keys_and_values, {
		key = 'oauth_signature',
		val = oauth_encode(hmac_b64)
	})

	-- Create the final query string and the Authorization header
	--
	local arg_header = { }
	local arg_query = { }

	for _, rec in pairs(keys_and_values) do
		if (rec.key:match('^oauth_')) then
			table.insert(arg_header, rec.key .. '="' .. rec.val .. '"')
		else
			table.insert(arg_query, rec.key .. '=' .. rec.val)
		end
	end

	query_string = table.concat(arg_query, '&')

	if method == 'GET' then
		-- Return the full URL and query string
		query_string = url .. "?" .. query_string
	end

	return query_string, {
		{ field = 'Authorization', value = 'OAuth ' .. table.concat(arg_header, ",") },
		{ field = 'Content-Type', value = 'application/x-www-form-urlencoded' }
	}
end


--------------------------------------------------------------------------------
-- GetUserPIN()
--
-- Show a dialog to the user inviting them to enter the authentication code
-- the tumblr page should have shown them after they granted this
-- application permission for access.
--
-- We return the PIN (as a string) if they provide it, nil otherwise.
--------------------------------------------------------------------------------

local function GetUserPIN(context)

	local PropertyTable = LrBinding.makePropertyTable(context)
	PropertyTable.PIN = ""

	local v = LrView.osFactory()
	local result = LrDialogs.presentModalDialog {

		title = LOC("$$$/xxx=Tumblr Authentication PIN"),
		contents = v:view {
			bind_to_object = PropertyTable,

			v:static_text {
				title = LOC("$$$/xxx=After you have granted this application access at Tumblr, paste the code they provided here:")
			},

			v:view {
				margin_top    = 20,
				place_horizontal = 0.5,
				place = 'horizontal',

				v:static_text {
					title = "Authentication Code:",
					font = { name = "<system/default>", size = 40 }
				},

				v:spacer { width = 10 },

				v:edit_field {
					width_in_chars = 30,
					wraps = false,
					alignment = 'center',
					value = LrView.bind 'PIN',
					font = { name = "<system/default>", size = 40 },

					validate = function(view, value)
						if value:match('^[0-9a-zA-Z]+$') then
							return true, value
						else
							return false, value, LOC("$$$/xxx=Invalid authentication code!")
						end
					end
				}
			}
		}
	}

	if result == "ok" then
		return PropertyTable.PIN
	else
		return nil
	end
end


--------------------------------------------------------------------------------
-- error_from_header()
--
-- If an HTTP request returns nothing, check the headers and return
-- some kind of reasonable error message.
--------------------------------------------------------------------------------

local function error_from_header(reply, headers)

	if not headers.status then
		return LOC("$$$/xxx=couldn't connect to tumblr -- Internet connection down?")
	end

	local note = LOC("$$$/xxx=Unexpected HTTP error reply #^1 from Tumblr", headers.status)

	if reply then
		note = note .. reply
		local error = reply:match("<error>(.-)</error>")
		if error then
			note = note .. ": " .. error
		end
	end

	return note
end


--------------------------------------------------------------------------------
-- Tumblr_AuthenticateNewCredentials()
--
-- Start a sequence that allows the user to authenticate their Tumblr account
-- to the plugin. This can't be run on the main LR task, so be sure it's downwind
-- of a LrTask.startAsyncTask() or LrFunctionContext.postAsyncTaskWithContext().
--
-- On failure, it returns nil and an error message.
--
-- On success, it returns a "credential bundle" table along the lines of:
--       
--       {
--          oauth_token        = "jahdhYHajdkajaeh"
--          oauth_token_secret = "GFWFGN$7gIN9Nf8huN&G^G#736nx7N&ZY#SyZz",
--       }
--
-- One should cache this credential-bundle table somewhere (e.g. in the
-- Lightroom Prefs) and use it for subsequent interaction with Tumblr on behalf
-- of the user, forever, unless attempting to use it results in an error
-- (at which point you probably want to uncache it).
--------------------------------------------------------------------------------

function Tumblr_AuthenticateNewCredentials()

	-- Create a signed query string for the "Request Token" request
	--
	local query, header_field = oauth_sign(TumblrRequestTokenURL(),
		'POST',
		{
			oauth_callback     = TumblrCallbackURL()
		},
		'text/plain'
	)

	-- Issue the "Request Token" request
	--
	--local result, headers = LrHttp.post("http://intranet.grufty.net/sandbox/query.php", "", 
	local result, headers = LrHttp.post(TumblrRequestTokenURL(), "", header_field)

	-- Abort if an error occured
	--
	if not result or headers.status ~= 200 then
		return nil, "ERROR", error_from_header(result, headers)
	end

	-- Extract the request token from the HTTP result
	--
	local token        = result:match('oauth_token=([^&]+)')
	local token_secret = result:match('oauth_token_secret=([^&]+)')

	if not token then
		return nil, "ERROR", LOC("$$$/xxx=couldn't get request token from Tumblr")
	end

	-- Tell the user that they'll have to permission their account to allow this
	-- app to have access, and give them a chance to bail.
	--
	local url = TumblrAuthorizeURL() .. '?oauth_token=' .. oauth_encode(token)

	local result = LrDialogs.confirm(
		LOC("$$$/xxx=To upload images to Tumblr, you must grant this plug-in permission. Open the authentication page at Tumblr?"),
		LOC("$$$/xxx=If you are currently logged into Tumblr with your browser, you will authenticate under that login."),
		LOC("$$$/xxx=View authentication page at Tumblr")
	)

	-- Abort if user decides to cancel
	--
	if result ~= "ok" then
		return nil, "The authentication process was cancelled."
	end

	-- Now have the user visit the authorize url (with that token) to log in to Tumblr
	-- and permission their account for your application.
	--
	LrHttp.openUrlInBrowser(url)
	LrTasks.sleep(1) -- give the browser a chance to open

	-- Now get PIN from user
	--
	local PIN

	LrFunctionContext.callWithContext("Tumblr authentication PIN", function(context)
                 PIN = GetUserPIN(context)
	end)

	if not PIN then
		return nil, "The authentication process was cancelled."
	end

	-- Now that the plugin should have permission, go to Tumblr and get the
	-- authentication token that will let us interact with Tumblr on behalf of the
	-- user.
	--
	local query, header_field = oauth_sign(TumblrAccessTokenURL(),
		'POST',
		{
			oauth_callback     = TumblrCallbackURL(),
			oauth_token        = token,
			oauth_token_secret = token_secret,
			oauth_verifier     = PIN,
		},
		'text/plain'
	)

	local result, headers = LrHttp.post(TumblrAccessTokenURL(), "", header_field)

	if not result or headers.status ~= 200 then
		return nil, error_from_header(result, headers)
	end

	local oauth_token        = result:match('oauth_token=([^&]+)')
	local oauth_token_secret = result:match('oauth_token_secret=([^&]+)')

	-- Got it
	--
	if oauth_token and oauth_token_secret then
		return {
			oauth_token        = oauth_token,
			oauth_token_secret = oauth_token_secret
		}
	end

	return nil, LOC("$$$/xxx=Unexpected reply from Tumblr: ^1",  result)
end
