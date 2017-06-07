--[[----------------------------------------------------------------------------

Lightroom2Tumblr

TumblrExportTask.lua - Upload photos to Tumblr

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

-- Lightroom API
local LrPathUtils = import 'LrPathUtils'
local LrHttp = import 'LrHttp'
local LrFileUtils = import 'LrFileUtils'
local LrErrors = import 'LrErrors'
local LrDialogs = import 'LrDialogs'
local prefs = import 'LrPrefs'.prefsForPlugin()

require 'Info' 

TumblrUploadTask = { }

--------------------------------------------------------------------------------
-- processRenderedPhotos()
--------------------------------------------------------------------------------

function TumblrUploadTask.processRenderedPhotos( functionContext, exportContext )

	-- Make a local reference to the export parameters.
	--
	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable
	local blogname = exportParams.blogname
	local privacy = exportParams.privacy
	local tags = exportParams.tags
	local extraCaption = exportParams.extraCaption
	local postStatus = exportParams.postStatus
	local ctURL = exportParams.ctURL
	local postTwitter = exportParams.postTwitter
	local exportTitle = exportParams.exportTitle
	local exportCaption = exportParams.exportCaption
	local exportKeywords = exportParams.exportKeywords
	local is_photoset = exportParams.is_photoset

	-- Check for existing Tumblr credentials
	--
	local tc = prefs.tumblr_credentials

	if tc == nil then
		LrDialogs.message(
			"No Tumblr Authentication", 
			"Please authenticate the plug-in in the Export settings menu first."
		)
		return
	end

	-- Construct Tumblr post URL (must be https scheme since May 2017)
	--
	local TumblrPostURL = TumblrApiURL() .. blogname .. TumblrApiEndpoint()

	-- Set progress title.
	--
	local nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1
		and LOC( "$$$/TumblrUpload/Upload/Progress=Uploading ^1 photos to Tumblr", nPhotos )
		or LOC "$$$/TumblrUpload/Upload/Progress/One=Uploading one photo to Tumblr",
	}

	-- Iterate through photo renditions.
	--
	local failures = {}

	for i, rendition in exportContext:renditions{ stopIfCanceled = true } do
	
		-- Get next photo.
		--
		local photo = rendition.photo
		local success, pathOrMessage = rendition:waitForRender()

		-- Check for cancellation again after photo has been rendered.
		--
		if progressScope:isCanceled() then 
			break 
		end
		
		if success then
			
			local filename = LrPathUtils.leafName( pathOrMessage )
			
			-- Create the basic POST request body
			--
			local post_request = {
				oauth_token = tc.oauth_token,
				oauth_token_secret = tc.oauth_token_secret,
				type = 'photo',
				format = 'html',
				state = postStatus,
				tweet = 'off',
				caption = '',
				tags = '',
				body = ''
			}

			-- Get the photo's title and caption metadata
			--
			local p_title = ''
			if exportTitle then
				p_title = photo:getFormattedMetadata('title') 
			end

			local p_caption = ''
			if exportCaption then
				p_caption = photo:getFormattedMetadata('caption')
			end

			-- Construct the Twitter string, if requested
			--
			if postTwitter ~= '' then
				-- Substitute %t with the title
				postTwitter = postTwitter:gsub("%%t", p_title:gsub("%%[tc]", "") or p_title )

				-- Substitute %c with the caption
				postTwitter = postTwitter:gsub("%%c", p_caption:gsub("%%[tc]", "") or p_caption )

				-- Truncate to 140 chars
				post_request.tweet = postTwitter:sub(1, 140)
			end

			-- Construct the photo's caption from title and/or caption metadata
			--
			if p_caption ~= '' then
				p_caption = '<p>' .. p_caption .. '</p>'
				post_request.caption = p_caption
			end

			if p_title ~= '' then
				if p_caption ~= '' then
					post_request.caption = '<strong>' .. p_title .. '</strong>' .. p_caption
				else
					post_request.caption = '<p>' .. p_title .. '</p>'
				end
			end

			-- Add extra caption text if specfied
			--
			if extraCaption ~= '' then
				post_request.caption = post_request.caption .. '<p>' .. extraCaption .. '</p>'
			end

			-- Get keyword list from metadata
			--
			if exportKeywords then
				post_request.tags = photo:getFormattedMetadata('keywordTagsForExport')
			end

			-- Add extra keywords from export settings
			--
			if tags ~= '' then
				post_request.tags = post_request.tags .. ',' .. tags
			end
			
			-- Add optional click-through URL
			--
			if ctURL ~= '' then 
				post_request.link = ctURL
			end

			-- Add encoded image data
			--
			post_request[ 'data[0]' ] = LrFileUtils.readFile( pathOrMessage )

			-- Created an OAuth signed POST request for the photo
			--
			local query, header_field = oauth_sign( TumblrPostURL, 'POST', post_request )

			-- Upload the photo
			--
			local result = nil
			local header = nil
			local status = nil

			result, header = LrHttp.post( TumblrPostURL, query, header_field, 'POST' ) 

			if result ~= nil then
				status = result:match('"status":([0-9]+)')
			else
				-- if we can't upload that file, log it.
				table.insert( failures, filename )
			end

			-- Check for "401 Not Authorized" error
			--
			if status == '401' then
				LrDialogs.message("Tumblr Authentication Failed", "It appears that the Tumblr credentials for this plug-in are no longer valid. Please logout and re-authenticate the plug-in in the Export settings menu.")
				
				-- Uncache credentials
				prefs.tumblr_credentials = nil
				table.insert( failures, filename )
				break
			elseif status ~= '201' then
				-- if we can't upload that file, log it.
				table.insert( failures, filename )
			end

			-- When done, delete temp file. There is a cleanup step that happens later,
			-- but this will help manage space in the event of a large upload.
			--
			LrFileUtils.delete( pathOrMessage )				
		end
	end

	if #failures > 0 then
		local message
		if #failures == 1 then
			message = LOC "$$$/TumblrUpload/Upload/Errors/OneFileFailed=1 file failed to upload correctly."
		else
			message = LOC ( "$$$/TumblrUpload/Upload/Errors/SomeFileFailed=^1 files failed to upload correctly.", #failures )
		end
		LrDialogs.message( message, table.concat( failures, "\n" ) )
	end
end
