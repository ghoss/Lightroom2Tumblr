--[[----------------------------------------------------------------------------

Lightroom2Tumblr

TumblrServiceProvider.lua - Service provider description

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
local LrView = import 'LrView'

-- TumblrUpload plug-in
require 'TumblrDialog'
require 'TumblrExportTask'


return {
	
	hideSections = { 'exportLocation', 'fileNaming', 'video' },
	allowFileFormats = {'JPEG'}, -- nil equates to all available formats
	allowColorSpaces = {'sRGB'}, -- nil equates to all color spaces
	hidePrintResolution = true,
	canExportVideo = false,

	exportPresetFields = {
		{ key = 'blogname', default = "myblogname" },
		{ key = 'privacy', default = "0" },
		{ key = 'postStatus', default = "published" },
		{ key = 'ctURL', default = '' },
		{ key = 'tags', default = '' },
		{ key = 'extraCaption', default = '' },
		{ key = 'postTwitter', default = "New Photo: %t" },
		{ key = 'exportTitle', default = true },
		{ key = 'exportCaption', default = true },
		{ key = 'exportKeywords', default = true },
		{ key = 'is_photoset', default = false },
		{ key = 'LR_size_doConstrain', default = true },
		{ key = 'LR_size_doNotEnlarge', default = true },
		{ key = 'LR_size_maxHeight', default = "1280" },
		{ key = 'LR_size_maxWidth', default = "1280" },
		{ key = 'LR_size_units', default = "pixels" },
		{ key = 'LR_size_resizeType', default = "wh" },
		{ key = 'LR_jpeg_quality', default = "75" },
		{ key = 'LR_outputSharpeningOn', default = true },
		{ key = 'LR_outputSharpeningMedia', default = "screen" },
		{ key = 'LR_outputSharpeningLevel', default = "2" },
		{ key = 'LR_useWatermark', default = false },
	},

	startDialog = TumblrDlgSections.startDialog,
	sectionsForTopOfDialog = TumblrDlgSections.sectionsForTopOfDialog,
	processRenderedPhotos = TumblrUploadTask.processRenderedPhotos,
	updateExportSettings = TumblrUploadTask.updateExportSettings
}
