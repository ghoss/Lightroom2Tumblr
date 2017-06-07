--[[----------------------------------------------------------------------------

Lightroom2Tumblr

LrSHA1.lua - SHA1 algorithm implementation with Lightroom bit functions.

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
local LrMath = import 'LrMath'
local bXOR = LrMath.bitXor
local bAND = LrMath.bitAnd
local bOR = LrMath.bitOr


-- local storing of global functions (minor speedup)
--
local floor,modf = math.floor,math.modf
local char,format,rep = string.char,string.format,string.rep

	
--------------------------------------------------------------------------------
-- bytes_to_w32()
--
-- merge 4 bytes to an 32 bit word
--------------------------------------------------------------------------------

local function bytes_to_w32 (a,b,c,d) 
	return a * 0x1000000 + b * 0x10000 + c * 0x100 + d 
end


--------------------------------------------------------------------------------
-- shift32()
--
-- shift the bits of a 32 bit word. Don't use negative values for "bits"
--------------------------------------------------------------------------------

local function shift32 (bits, a)
	local b2 = 2 ^ (32 - bits)
	local a, b = modf(a / b2)
	return a + b * b2 * (2 ^ (bits))
end


--------------------------------------------------------------------------------
-- add32()
--
-- adding 2 32bit numbers, cutting off the remainder on 33th bit
--------------------------------------------------------------------------------

local function add32 (a,b) 
	return (a + b) % 4294967296 
end


--------------------------------------------------------------------------------
-- bNOT()
--
-- binary complement for 32bit numbers
--------------------------------------------------------------------------------

local function bNOT (a)
	return 4294967295 - (a % 4294967296)
end


--------------------------------------------------------------------------------
-- w32_to_hexstring()
--
-- converting the number to a hexadecimal string
--------------------------------------------------------------------------------

local function w32_to_hexstring (w) 
	return format("%08x", w) 
end


--------------------------------------------------------------------------------
-- hex_to_binary()
--------------------------------------------------------------------------------

local function hex_to_binary(hex)
	return hex:gsub('..', function(hexval)
		return string.char(tonumber(hexval, 16))
	end)
end


-------------------------------------------------------------------------------
-- sha1(msg)
-------------------------------------------------------------------------------

function sha1(msg)
	local H0,H1,H2,H3,H4 = 0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
	local msg_len_in_bits = #msg * 8

	local first_append = char(0x80) -- append a '1' bit plus seven '0' bits

	local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
	local current_mod = non_zero_message_bytes % 64
	local second_append = current_mod>0 and rep(char(0), 64 - current_mod) or ""

	-- now to append the length as a 64-bit number.
	local B1, R1 = modf(msg_len_in_bits  / 0x01000000)
	local B2, R2 = modf( 0x01000000 * R1 / 0x00010000)
	local B3, R3 = modf( 0x00010000 * R2 / 0x00000100)
	local B4 = 0x00000100 * R3

	local L64 = char( 0) .. char( 0) .. char( 0) .. char( 0) -- high 32 bits
			.. char(B1) .. char(B2) .. char(B3) .. char(B4) --  low 32 bits

	msg = msg .. first_append .. second_append .. L64

	assert(#msg % 64 == 0)

	local chunks = #msg / 64

	local W = { }
	local start, A, B, C, D, E, f, K, TEMP
	local chunk = 0

	while chunk < chunks do
		--
		-- break chunk up into W[0] through W[15]
		--
		start,chunk = chunk * 64 + 1,chunk + 1

		for t = 0, 15 do
			W[t] = bytes_to_w32(msg:byte(start, start + 3))
			start = start + 4
		end

		--
		-- build W[16] through W[79]
		--
		for t = 16, 79 do
			-- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16).
			W[t] = shift32(1, bXOR(bXOR(bXOR(W[t-3], W[t-8]), W[t-14]), W[t-16]))
		end

		A,B,C,D,E = H0,H1,H2,H3,H4

		for t = 0, 79 do
			if t <= 19 then
				-- (B AND C) OR ((NOT B) AND D)
				f = bOR(bAND(B, C), bAND(bNOT(B), D))
				K = 0x5A827999
			elseif t <= 39 then
				-- B XOR C XOR D
				f = bXOR(bXOR(B, C), D)
				K = 0x6ED9EBA1
			elseif t <= 59 then
				-- (B AND C) OR (B AND D) OR (C AND D)
				f = bOR(bAND(B, C), bOR(bAND(B, D), bAND(C, D)))
				K = 0x8F1BBCDC
			else
				-- B XOR C XOR D
				f = bXOR(bXOR(B, C), D)
				K = 0xCA62C1D6
			end

			-- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt;
			local tmp = add32(add32(add32(add32(shift32(5, A), f), E), W[t]), K)
			A,B,C,D,E = tmp, A, shift32(30, B), C, D
		end
		-- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E.
		H0,H1,H2,H3,H4 = add32(H0, A), add32(H1, B), add32(H2, C), add32(H3, D), add32(H4, E)
	end

	local f = w32_to_hexstring
	return f(H0) .. f(H1) .. f(H2) .. f(H3) .. f(H4)
end


-------------------------------------------------------------------------------
-- sha1_binary()
-------------------------------------------------------------------------------

function sha1_binary(msg)
	return hex_to_binary(sha1(msg))
end


-------------------------------------------------------------------------------
-- hmac_sha1()
-------------------------------------------------------------------------------

local xor_with_0x5c = { }
local xor_with_0x36 = { }

-- building the lookuptables ahead of time (instead of littering the source code
-- with precalculated values)
--
for i= 0, 0xff do
	xor_with_0x5c[char(i)] = char(bXOR(i, 0x5c))
	xor_with_0x36[char(i)] = char(bXOR(i, 0x36))
end

local blocksize = 64 -- 512 bits

function hmac_sha1(key, text)
	assert(type(key)  == 'string', "key passed to hmac_sha1 should be a string")
	assert(type(text) == 'string', "text passed to hmac_sha1 should be a string")

	if #key > blocksize then
		key = sha1_binary(key)
	end

	local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
	local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)

	return sha1(key_xord_with_0x5c .. sha1_binary(key_xord_with_0x36 .. text))
end


-------------------------------------------------------------------------------
-- hmac_sha1_binary()
-------------------------------------------------------------------------------

function hmac_sha1_binary(key, text)
	return hex_to_binary(hmac_sha1(key, text))
end
