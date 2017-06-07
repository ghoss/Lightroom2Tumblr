--[[----------------------------------------------------------------------------

Lightroom2Tumblr

TumblrDialog.lua - Export dialog customization

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

-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local prefs = import 'LrPrefs'.prefsForPlugin()

require 'Info'
require 'TumblrAuthentication'

TumblrDlgSections = { }


--------------------------------------------------------------------------------
-- sectionsForTopOfDialog()
--------------------------------------------------------------------------------

function TumblrDlgSections.sectionsForTopOfDialog( f, pt )

	local f = LrView.osFactory()
	local bind = LrView.bind

	local result = { 

	-- Section 1: Tumblr Account Settings
	--
	{
		title = "Tumblr Account Settings",

		f:row {
			f:static_text {
				title= " Tumblr Blog Name:"
			},
			f:spacer { 
				width = 0
			},
			f:edit_field {
				title = "blogname",
				value = bind 'blogname',
				width_in_chars = 10
			},
			f:static_text {
				title=".tumblr.com"
			},
		},

		f:view {
			bind_to_object = prefs,
			place = 'overlapping',
			fill_horizontal = 1,

			f:row {
				f:static_text {
					visible = LrBinding.keyIsNotNil 'tumblr_credentials',
					title = "Successfully authenticated at Tumblr.",
				},

				f:spacer { 
					visible = LrBinding.keyIsNotNil 'tumblr_credentials',
					width = 5
				},

				f:push_button {
					visible = LrBinding.keyIsNotNil 'tumblr_credentials',
					title = "Logout from Tumblr",

					-- Revoke permissions by uncaching credential bundle
					--
					action = function(button)
						prefs.tumblr_credentials = nil
					end
				}
			},

			f:push_button {
				visible = LrBinding.keyIsNil 'tumblr_credentials',
				enabled = LrBinding.keyIsNil 'tumblr_authenticating',
				height_in_lines = 2,
				title   = "Authenticate at Tumblr",

				action  = function(button)
					LrFunctionContext.postAsyncTaskWithContext("tumblr auth task",
					function(context)

						context:addFailureHandler(function(status, error)
							LrDialogs.message("INTERNAL ERROR", error, "critical")
						end)

						context:addCleanupHandler(function()
							prefs.tumblr_authenticating = nil
						end)

						prefs.tumblr_authenticating = true

						local res, err, opt = Tumblr_AuthenticateNewCredentials()

						if res == nil then
							LrDialogs.message(err, opt, "warning")
						end
						prefs.tumblr_credentials = res
					end)
				end
			}
		},
	},

	-- Section 2: Tumblr Post Details
	--
	{
		title = "Tumblr Post Details",

		f:row {
			f:checkbox {
				title = "Export as photoset",
				value = bind 'is_photoset'
			},	
		},

		f:row {
			f:static_text {
				title = "Export Metadata:",
			},
			f:spacer { width = 4 },
			f:checkbox {
				title = "Title",
				value = bind 'exportTitle'
			},	
			f:spacer { width = 4 },
			f:checkbox {
				title = "Caption",
				value = bind 'exportCaption'
			},	
			f:spacer { width = 4 },
			f:checkbox {
				title = "Keywords",
				value = bind 'exportKeywords'
			},	
		},

		f:row {
			f:static_text {
				title = "Extra Tags - Comma Separated (Optional)",
			},
			f:spacer { width = 3 },
			f:edit_field {
				title = 'tags',
				value = bind 'tags',
				width_in_chars = 25,
			},
		},

		f:row {
			f:static_text {
				title = "Extra Caption Text (Optional)",
			},
			f:spacer { width = 3 },
			f:edit_field {
				title = 'extraCaption',
				value = bind 'extraCaption',
				width_in_chars = 25,
			},
		},
					
		f:row {
			f:static_text {
				title = "Click-Through URL (Optional)",
			},
			f:spacer { width = 4 },
			f:edit_field {
				title = 'ctURL',
				value = bind 'ctURL',
				width_in_chars = 25,
				height_in_lines = 1,
			},
		},

		f:row {
			f:static_text {
				title = "Twitter Text (Optional)",
			},
			f:spacer { width = 4 },
			f:edit_field {
				title = 'postTwitter',
				value = bind 'postTwitter',
				width_in_chars = 25,
				height_in_lines = 1,
			},
		},
		
		f:row {
			f:column {
				f:static_text {
					title = "Private Post:",
				}
			},
			f:popup_menu {
				title = "privacy",
				value = bind 'privacy',
				items = {
					{ title = "Yes", value = '1' },
					{ title = "No", value = '0' },
				}
			},
		},
		
		f:row {
			f:static_text {
				title = "Post Status",
			},
			f:popup_menu {
				title = "postStatus",
				value = bind 'postStatus',
				items = {
					{ title = "Publish Now", value = 'published' },
					{ title = "Save as draft", value = 'draft' },
					{ title = "Add to queue", value = 'queue' },
				}
			}
		}
	} }
	
	return result
end


--------------------------------------------------------------------------------
-- startDialog()
--------------------------------------------------------------------------------

function updateDlgStatus( pt )
		
	local message = nil
	
	if pt.blogname == nil then
		message = "Enter the tumblr blog name to post to."
	end
	
	if message then
		pt.message = message
		pt.hasError = true
		pt.hasNoError = false
		pt.LR_canExport = false
		pt.LR_cantExportBecause = message
	else
		pt.message = nil
		pt.hasError = false
		pt.hasNoError = true
		pt.LR_canExport = true
	end
end


function TumblrDlgSections.startDialog( pt )
	pt:addObserver( 'blogname', updateDlgStatus )
	updateDlgStatus( pt )
end
