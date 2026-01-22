local Const = require 'scripts.constants'

local Terrain = {}

local math_abs    = math.abs
local math_max    = math.max
local math_sqrt   = math.sqrt
local math_ceil   = math.ceil
local math_floor  = math.floor
local math_random = math.random

local _data = prototypes.mod_data.minesweeper.data
local RICHNESS        = _data.richness
local SAND_ORES       = _data.frequencies.sand
local GRASS_ORES      = _data.frequencies.grass
local DEFAULT_TILE    = 'nuclear-ground'
local FORCE_NAME      = Const.FORCE_NAME
local SURFACE_INDEX   = Const.SURFACE_INDEX
local UNIT_SPAWNER_ID = Const.UNIT_SPAWNER_ID

local TILES_MAP = {
    [1] = 'water-shallow',
    [2] = 'sand-1',
    [3] = 'sand-2',
    [4] = 'sand-3',
    [5] = 'grass-1',
    [6] = 'grass-2',
    [7] = 'grass-3',
}

local NUCLEAR_CORPSES = { type = 'corpse', name = 'huge-scorchmark' }
local NUCLEAR_DECORATIVES = { name = 'nuclear-ground-patch' }
local EXPLOSIONS = {
    'atomic-bomb-ground-zero-projectile',
    'atomic-bomb-wave',
    'atomic-bomb-wave-spawns-cluster-nuke-explosion',
    'atomic-bomb-wave-spawns-fire-smoke-explosion',
    'atomic-bomb-wave-spawns-nuclear-smoke',
    'atomic-bomb-wave-spawns-nuke-shockwave-explosion',
    'atomic-rocket'
}

---------------------------------------------------------
-- TERRAIN
---------------------------------------------------------

---@param surface LuaSurface
---@param chunkpos ChunkPosition
---@return table<number>
local function calculate_noise_chunk(surface, chunkpos)
	local x, y = chunkpos.x * 32, chunkpos.y * 32

	local positions = {{x,y},{x,y+1},{x,y+2},{x,y+3},{x,y+4},{x,y+5},{x,y+6},{x,y+7},{x,y+8},{x,y+9},{x,y+10},{x,y+11},{x,y+12},{x,y+13},{x,y+14},{x,y+15},{x,y+16},{x,y+17},{x,y+18},{x,y+19},{x,y+20},{x,y+21},{x,y+22},{x,y+23},{x,y+24},{x,y+25},{x,y+26},{x,y+27},{x,y+28},{x,y+29},{x,y+30},{x,y+31},
	{x+1,y},{x+1,y+1},{x+1,y+2},{x+1,y+3},{x+1,y+4},{x+1,y+5},{x+1,y+6},{x+1,y+7},{x+1,y+8},{x+1,y+9},{x+1,y+10},{x+1,y+11},{x+1,y+12},{x+1,y+13},{x+1,y+14},{x+1,y+15},{x+1,y+16},{x+1,y+17},{x+1,y+18},{x+1,y+19},{x+1,y+20},{x+1,y+21},{x+1,y+22},{x+1,y+23},{x+1,y+24},{x+1,y+25},{x+1,y+26},{x+1,y+27},{x+1,y+28},{x+1,y+29},{x+1,y+30},{x+1,y+31},
	{x+2,y},{x+2,y+1},{x+2,y+2},{x+2,y+3},{x+2,y+4},{x+2,y+5},{x+2,y+6},{x+2,y+7},{x+2,y+8},{x+2,y+9},{x+2,y+10},{x+2,y+11},{x+2,y+12},{x+2,y+13},{x+2,y+14},{x+2,y+15},{x+2,y+16},{x+2,y+17},{x+2,y+18},{x+2,y+19},{x+2,y+20},{x+2,y+21},{x+2,y+22},{x+2,y+23},{x+2,y+24},{x+2,y+25},{x+2,y+26},{x+2,y+27},{x+2,y+28},{x+2,y+29},{x+2,y+30},{x+2,y+31},
	{x+3,y},{x+3,y+1},{x+3,y+2},{x+3,y+3},{x+3,y+4},{x+3,y+5},{x+3,y+6},{x+3,y+7},{x+3,y+8},{x+3,y+9},{x+3,y+10},{x+3,y+11},{x+3,y+12},{x+3,y+13},{x+3,y+14},{x+3,y+15},{x+3,y+16},{x+3,y+17},{x+3,y+18},{x+3,y+19},{x+3,y+20},{x+3,y+21},{x+3,y+22},{x+3,y+23},{x+3,y+24},{x+3,y+25},{x+3,y+26},{x+3,y+27},{x+3,y+28},{x+3,y+29},{x+3,y+30},{x+3,y+31},
	{x+4,y},{x+4,y+1},{x+4,y+2},{x+4,y+3},{x+4,y+4},{x+4,y+5},{x+4,y+6},{x+4,y+7},{x+4,y+8},{x+4,y+9},{x+4,y+10},{x+4,y+11},{x+4,y+12},{x+4,y+13},{x+4,y+14},{x+4,y+15},{x+4,y+16},{x+4,y+17},{x+4,y+18},{x+4,y+19},{x+4,y+20},{x+4,y+21},{x+4,y+22},{x+4,y+23},{x+4,y+24},{x+4,y+25},{x+4,y+26},{x+4,y+27},{x+4,y+28},{x+4,y+29},{x+4,y+30},{x+4,y+31},
	{x+5,y},{x+5,y+1},{x+5,y+2},{x+5,y+3},{x+5,y+4},{x+5,y+5},{x+5,y+6},{x+5,y+7},{x+5,y+8},{x+5,y+9},{x+5,y+10},{x+5,y+11},{x+5,y+12},{x+5,y+13},{x+5,y+14},{x+5,y+15},{x+5,y+16},{x+5,y+17},{x+5,y+18},{x+5,y+19},{x+5,y+20},{x+5,y+21},{x+5,y+22},{x+5,y+23},{x+5,y+24},{x+5,y+25},{x+5,y+26},{x+5,y+27},{x+5,y+28},{x+5,y+29},{x+5,y+30},{x+5,y+31},
	{x+6,y},{x+6,y+1},{x+6,y+2},{x+6,y+3},{x+6,y+4},{x+6,y+5},{x+6,y+6},{x+6,y+7},{x+6,y+8},{x+6,y+9},{x+6,y+10},{x+6,y+11},{x+6,y+12},{x+6,y+13},{x+6,y+14},{x+6,y+15},{x+6,y+16},{x+6,y+17},{x+6,y+18},{x+6,y+19},{x+6,y+20},{x+6,y+21},{x+6,y+22},{x+6,y+23},{x+6,y+24},{x+6,y+25},{x+6,y+26},{x+6,y+27},{x+6,y+28},{x+6,y+29},{x+6,y+30},{x+6,y+31},
	{x+7,y},{x+7,y+1},{x+7,y+2},{x+7,y+3},{x+7,y+4},{x+7,y+5},{x+7,y+6},{x+7,y+7},{x+7,y+8},{x+7,y+9},{x+7,y+10},{x+7,y+11},{x+7,y+12},{x+7,y+13},{x+7,y+14},{x+7,y+15},{x+7,y+16},{x+7,y+17},{x+7,y+18},{x+7,y+19},{x+7,y+20},{x+7,y+21},{x+7,y+22},{x+7,y+23},{x+7,y+24},{x+7,y+25},{x+7,y+26},{x+7,y+27},{x+7,y+28},{x+7,y+29},{x+7,y+30},{x+7,y+31},
	{x+8,y},{x+8,y+1},{x+8,y+2},{x+8,y+3},{x+8,y+4},{x+8,y+5},{x+8,y+6},{x+8,y+7},{x+8,y+8},{x+8,y+9},{x+8,y+10},{x+8,y+11},{x+8,y+12},{x+8,y+13},{x+8,y+14},{x+8,y+15},{x+8,y+16},{x+8,y+17},{x+8,y+18},{x+8,y+19},{x+8,y+20},{x+8,y+21},{x+8,y+22},{x+8,y+23},{x+8,y+24},{x+8,y+25},{x+8,y+26},{x+8,y+27},{x+8,y+28},{x+8,y+29},{x+8,y+30},{x+8,y+31},
	{x+9,y},{x+9,y+1},{x+9,y+2},{x+9,y+3},{x+9,y+4},{x+9,y+5},{x+9,y+6},{x+9,y+7},{x+9,y+8},{x+9,y+9},{x+9,y+10},{x+9,y+11},{x+9,y+12},{x+9,y+13},{x+9,y+14},{x+9,y+15},{x+9,y+16},{x+9,y+17},{x+9,y+18},{x+9,y+19},{x+9,y+20},{x+9,y+21},{x+9,y+22},{x+9,y+23},{x+9,y+24},{x+9,y+25},{x+9,y+26},{x+9,y+27},{x+9,y+28},{x+9,y+29},{x+9,y+30},{x+9,y+31},
	{x+10,y},{x+10,y+1},{x+10,y+2},{x+10,y+3},{x+10,y+4},{x+10,y+5},{x+10,y+6},{x+10,y+7},{x+10,y+8},{x+10,y+9},{x+10,y+10},{x+10,y+11},{x+10,y+12},{x+10,y+13},{x+10,y+14},{x+10,y+15},{x+10,y+16},{x+10,y+17},{x+10,y+18},{x+10,y+19},{x+10,y+20},{x+10,y+21},{x+10,y+22},{x+10,y+23},{x+10,y+24},{x+10,y+25},{x+10,y+26},{x+10,y+27},{x+10,y+28},{x+10,y+29},{x+10,y+30},{x+10,y+31},
	{x+11,y},{x+11,y+1},{x+11,y+2},{x+11,y+3},{x+11,y+4},{x+11,y+5},{x+11,y+6},{x+11,y+7},{x+11,y+8},{x+11,y+9},{x+11,y+10},{x+11,y+11},{x+11,y+12},{x+11,y+13},{x+11,y+14},{x+11,y+15},{x+11,y+16},{x+11,y+17},{x+11,y+18},{x+11,y+19},{x+11,y+20},{x+11,y+21},{x+11,y+22},{x+11,y+23},{x+11,y+24},{x+11,y+25},{x+11,y+26},{x+11,y+27},{x+11,y+28},{x+11,y+29},{x+11,y+30},{x+11,y+31},
	{x+12,y},{x+12,y+1},{x+12,y+2},{x+12,y+3},{x+12,y+4},{x+12,y+5},{x+12,y+6},{x+12,y+7},{x+12,y+8},{x+12,y+9},{x+12,y+10},{x+12,y+11},{x+12,y+12},{x+12,y+13},{x+12,y+14},{x+12,y+15},{x+12,y+16},{x+12,y+17},{x+12,y+18},{x+12,y+19},{x+12,y+20},{x+12,y+21},{x+12,y+22},{x+12,y+23},{x+12,y+24},{x+12,y+25},{x+12,y+26},{x+12,y+27},{x+12,y+28},{x+12,y+29},{x+12,y+30},{x+12,y+31},
	{x+13,y},{x+13,y+1},{x+13,y+2},{x+13,y+3},{x+13,y+4},{x+13,y+5},{x+13,y+6},{x+13,y+7},{x+13,y+8},{x+13,y+9},{x+13,y+10},{x+13,y+11},{x+13,y+12},{x+13,y+13},{x+13,y+14},{x+13,y+15},{x+13,y+16},{x+13,y+17},{x+13,y+18},{x+13,y+19},{x+13,y+20},{x+13,y+21},{x+13,y+22},{x+13,y+23},{x+13,y+24},{x+13,y+25},{x+13,y+26},{x+13,y+27},{x+13,y+28},{x+13,y+29},{x+13,y+30},{x+13,y+31},
	{x+14,y},{x+14,y+1},{x+14,y+2},{x+14,y+3},{x+14,y+4},{x+14,y+5},{x+14,y+6},{x+14,y+7},{x+14,y+8},{x+14,y+9},{x+14,y+10},{x+14,y+11},{x+14,y+12},{x+14,y+13},{x+14,y+14},{x+14,y+15},{x+14,y+16},{x+14,y+17},{x+14,y+18},{x+14,y+19},{x+14,y+20},{x+14,y+21},{x+14,y+22},{x+14,y+23},{x+14,y+24},{x+14,y+25},{x+14,y+26},{x+14,y+27},{x+14,y+28},{x+14,y+29},{x+14,y+30},{x+14,y+31},
	{x+15,y},{x+15,y+1},{x+15,y+2},{x+15,y+3},{x+15,y+4},{x+15,y+5},{x+15,y+6},{x+15,y+7},{x+15,y+8},{x+15,y+9},{x+15,y+10},{x+15,y+11},{x+15,y+12},{x+15,y+13},{x+15,y+14},{x+15,y+15},{x+15,y+16},{x+15,y+17},{x+15,y+18},{x+15,y+19},{x+15,y+20},{x+15,y+21},{x+15,y+22},{x+15,y+23},{x+15,y+24},{x+15,y+25},{x+15,y+26},{x+15,y+27},{x+15,y+28},{x+15,y+29},{x+15,y+30},{x+15,y+31},
	{x+16,y},{x+16,y+1},{x+16,y+2},{x+16,y+3},{x+16,y+4},{x+16,y+5},{x+16,y+6},{x+16,y+7},{x+16,y+8},{x+16,y+9},{x+16,y+10},{x+16,y+11},{x+16,y+12},{x+16,y+13},{x+16,y+14},{x+16,y+15},{x+16,y+16},{x+16,y+17},{x+16,y+18},{x+16,y+19},{x+16,y+20},{x+16,y+21},{x+16,y+22},{x+16,y+23},{x+16,y+24},{x+16,y+25},{x+16,y+26},{x+16,y+27},{x+16,y+28},{x+16,y+29},{x+16,y+30},{x+16,y+31},
	{x+17,y},{x+17,y+1},{x+17,y+2},{x+17,y+3},{x+17,y+4},{x+17,y+5},{x+17,y+6},{x+17,y+7},{x+17,y+8},{x+17,y+9},{x+17,y+10},{x+17,y+11},{x+17,y+12},{x+17,y+13},{x+17,y+14},{x+17,y+15},{x+17,y+16},{x+17,y+17},{x+17,y+18},{x+17,y+19},{x+17,y+20},{x+17,y+21},{x+17,y+22},{x+17,y+23},{x+17,y+24},{x+17,y+25},{x+17,y+26},{x+17,y+27},{x+17,y+28},{x+17,y+29},{x+17,y+30},{x+17,y+31},
	{x+18,y},{x+18,y+1},{x+18,y+2},{x+18,y+3},{x+18,y+4},{x+18,y+5},{x+18,y+6},{x+18,y+7},{x+18,y+8},{x+18,y+9},{x+18,y+10},{x+18,y+11},{x+18,y+12},{x+18,y+13},{x+18,y+14},{x+18,y+15},{x+18,y+16},{x+18,y+17},{x+18,y+18},{x+18,y+19},{x+18,y+20},{x+18,y+21},{x+18,y+22},{x+18,y+23},{x+18,y+24},{x+18,y+25},{x+18,y+26},{x+18,y+27},{x+18,y+28},{x+18,y+29},{x+18,y+30},{x+18,y+31},
	{x+19,y},{x+19,y+1},{x+19,y+2},{x+19,y+3},{x+19,y+4},{x+19,y+5},{x+19,y+6},{x+19,y+7},{x+19,y+8},{x+19,y+9},{x+19,y+10},{x+19,y+11},{x+19,y+12},{x+19,y+13},{x+19,y+14},{x+19,y+15},{x+19,y+16},{x+19,y+17},{x+19,y+18},{x+19,y+19},{x+19,y+20},{x+19,y+21},{x+19,y+22},{x+19,y+23},{x+19,y+24},{x+19,y+25},{x+19,y+26},{x+19,y+27},{x+19,y+28},{x+19,y+29},{x+19,y+30},{x+19,y+31},
	{x+20,y},{x+20,y+1},{x+20,y+2},{x+20,y+3},{x+20,y+4},{x+20,y+5},{x+20,y+6},{x+20,y+7},{x+20,y+8},{x+20,y+9},{x+20,y+10},{x+20,y+11},{x+20,y+12},{x+20,y+13},{x+20,y+14},{x+20,y+15},{x+20,y+16},{x+20,y+17},{x+20,y+18},{x+20,y+19},{x+20,y+20},{x+20,y+21},{x+20,y+22},{x+20,y+23},{x+20,y+24},{x+20,y+25},{x+20,y+26},{x+20,y+27},{x+20,y+28},{x+20,y+29},{x+20,y+30},{x+20,y+31},
	{x+21,y},{x+21,y+1},{x+21,y+2},{x+21,y+3},{x+21,y+4},{x+21,y+5},{x+21,y+6},{x+21,y+7},{x+21,y+8},{x+21,y+9},{x+21,y+10},{x+21,y+11},{x+21,y+12},{x+21,y+13},{x+21,y+14},{x+21,y+15},{x+21,y+16},{x+21,y+17},{x+21,y+18},{x+21,y+19},{x+21,y+20},{x+21,y+21},{x+21,y+22},{x+21,y+23},{x+21,y+24},{x+21,y+25},{x+21,y+26},{x+21,y+27},{x+21,y+28},{x+21,y+29},{x+21,y+30},{x+21,y+31},
	{x+22,y},{x+22,y+1},{x+22,y+2},{x+22,y+3},{x+22,y+4},{x+22,y+5},{x+22,y+6},{x+22,y+7},{x+22,y+8},{x+22,y+9},{x+22,y+10},{x+22,y+11},{x+22,y+12},{x+22,y+13},{x+22,y+14},{x+22,y+15},{x+22,y+16},{x+22,y+17},{x+22,y+18},{x+22,y+19},{x+22,y+20},{x+22,y+21},{x+22,y+22},{x+22,y+23},{x+22,y+24},{x+22,y+25},{x+22,y+26},{x+22,y+27},{x+22,y+28},{x+22,y+29},{x+22,y+30},{x+22,y+31},
	{x+23,y},{x+23,y+1},{x+23,y+2},{x+23,y+3},{x+23,y+4},{x+23,y+5},{x+23,y+6},{x+23,y+7},{x+23,y+8},{x+23,y+9},{x+23,y+10},{x+23,y+11},{x+23,y+12},{x+23,y+13},{x+23,y+14},{x+23,y+15},{x+23,y+16},{x+23,y+17},{x+23,y+18},{x+23,y+19},{x+23,y+20},{x+23,y+21},{x+23,y+22},{x+23,y+23},{x+23,y+24},{x+23,y+25},{x+23,y+26},{x+23,y+27},{x+23,y+28},{x+23,y+29},{x+23,y+30},{x+23,y+31},
	{x+24,y},{x+24,y+1},{x+24,y+2},{x+24,y+3},{x+24,y+4},{x+24,y+5},{x+24,y+6},{x+24,y+7},{x+24,y+8},{x+24,y+9},{x+24,y+10},{x+24,y+11},{x+24,y+12},{x+24,y+13},{x+24,y+14},{x+24,y+15},{x+24,y+16},{x+24,y+17},{x+24,y+18},{x+24,y+19},{x+24,y+20},{x+24,y+21},{x+24,y+22},{x+24,y+23},{x+24,y+24},{x+24,y+25},{x+24,y+26},{x+24,y+27},{x+24,y+28},{x+24,y+29},{x+24,y+30},{x+24,y+31},
	{x+25,y},{x+25,y+1},{x+25,y+2},{x+25,y+3},{x+25,y+4},{x+25,y+5},{x+25,y+6},{x+25,y+7},{x+25,y+8},{x+25,y+9},{x+25,y+10},{x+25,y+11},{x+25,y+12},{x+25,y+13},{x+25,y+14},{x+25,y+15},{x+25,y+16},{x+25,y+17},{x+25,y+18},{x+25,y+19},{x+25,y+20},{x+25,y+21},{x+25,y+22},{x+25,y+23},{x+25,y+24},{x+25,y+25},{x+25,y+26},{x+25,y+27},{x+25,y+28},{x+25,y+29},{x+25,y+30},{x+25,y+31},
	{x+26,y},{x+26,y+1},{x+26,y+2},{x+26,y+3},{x+26,y+4},{x+26,y+5},{x+26,y+6},{x+26,y+7},{x+26,y+8},{x+26,y+9},{x+26,y+10},{x+26,y+11},{x+26,y+12},{x+26,y+13},{x+26,y+14},{x+26,y+15},{x+26,y+16},{x+26,y+17},{x+26,y+18},{x+26,y+19},{x+26,y+20},{x+26,y+21},{x+26,y+22},{x+26,y+23},{x+26,y+24},{x+26,y+25},{x+26,y+26},{x+26,y+27},{x+26,y+28},{x+26,y+29},{x+26,y+30},{x+26,y+31},
	{x+27,y},{x+27,y+1},{x+27,y+2},{x+27,y+3},{x+27,y+4},{x+27,y+5},{x+27,y+6},{x+27,y+7},{x+27,y+8},{x+27,y+9},{x+27,y+10},{x+27,y+11},{x+27,y+12},{x+27,y+13},{x+27,y+14},{x+27,y+15},{x+27,y+16},{x+27,y+17},{x+27,y+18},{x+27,y+19},{x+27,y+20},{x+27,y+21},{x+27,y+22},{x+27,y+23},{x+27,y+24},{x+27,y+25},{x+27,y+26},{x+27,y+27},{x+27,y+28},{x+27,y+29},{x+27,y+30},{x+27,y+31},
	{x+28,y},{x+28,y+1},{x+28,y+2},{x+28,y+3},{x+28,y+4},{x+28,y+5},{x+28,y+6},{x+28,y+7},{x+28,y+8},{x+28,y+9},{x+28,y+10},{x+28,y+11},{x+28,y+12},{x+28,y+13},{x+28,y+14},{x+28,y+15},{x+28,y+16},{x+28,y+17},{x+28,y+18},{x+28,y+19},{x+28,y+20},{x+28,y+21},{x+28,y+22},{x+28,y+23},{x+28,y+24},{x+28,y+25},{x+28,y+26},{x+28,y+27},{x+28,y+28},{x+28,y+29},{x+28,y+30},{x+28,y+31},
	{x+29,y},{x+29,y+1},{x+29,y+2},{x+29,y+3},{x+29,y+4},{x+29,y+5},{x+29,y+6},{x+29,y+7},{x+29,y+8},{x+29,y+9},{x+29,y+10},{x+29,y+11},{x+29,y+12},{x+29,y+13},{x+29,y+14},{x+29,y+15},{x+29,y+16},{x+29,y+17},{x+29,y+18},{x+29,y+19},{x+29,y+20},{x+29,y+21},{x+29,y+22},{x+29,y+23},{x+29,y+24},{x+29,y+25},{x+29,y+26},{x+29,y+27},{x+29,y+28},{x+29,y+29},{x+29,y+30},{x+29,y+31},
	{x+30,y},{x+30,y+1},{x+30,y+2},{x+30,y+3},{x+30,y+4},{x+30,y+5},{x+30,y+6},{x+30,y+7},{x+30,y+8},{x+30,y+9},{x+30,y+10},{x+30,y+11},{x+30,y+12},{x+30,y+13},{x+30,y+14},{x+30,y+15},{x+30,y+16},{x+30,y+17},{x+30,y+18},{x+30,y+19},{x+30,y+20},{x+30,y+21},{x+30,y+22},{x+30,y+23},{x+30,y+24},{x+30,y+25},{x+30,y+26},{x+30,y+27},{x+30,y+28},{x+30,y+29},{x+30,y+30},{x+30,y+31},
	{x+31,y},{x+31,y+1},{x+31,y+2},{x+31,y+3},{x+31,y+4},{x+31,y+5},{x+31,y+6},{x+31,y+7},{x+31,y+8},{x+31,y+9},{x+31,y+10},{x+31,y+11},{x+31,y+12},{x+31,y+13},{x+31,y+14},{x+31,y+15},{x+31,y+16},{x+31,y+17},{x+31,y+18},{x+31,y+19},{x+31,y+20},{x+31,y+21},{x+31,y+22},{x+31,y+23},{x+31,y+24},{x+31,y+25},{x+31,y+26},{x+31,y+27},{x+31,y+28},{x+31,y+29},{x+31,y+30},{x+31,y+31}}

    return surface.calculate_tile_properties({ 'ms_tile_dictionary_nauvis' }, positions).ms_tile_dictionary_nauvis
end

---@param surface LuaSurface
---@param positions table<MapPosition>
---@return table<string, table<number>>
local function calculate_noise(surface, positions)
	return surface.calculate_tile_properties({ 'ms_tile_dictionary_nauvis', 'ms_ore_richness_nauvis' }, positions)
end

---@param positions table<MapPosition>
---@return table<MapPosition>
local function unpack(positions)
	local result = {}
	for _, position in ipairs(positions) do
		for x = 0, 1 do
			for y = 0, 1 do
				result[#result+1] = { x = position.x + x - 0.5, y = position.y + y - 0.5 }
			end
		end
	end
	return result
end

---@param surface LuaSurface
---@param positions table<MapPosition>
---@param rewards table<boolean>
function Terrain.reveal_tiles(surface, positions, rewards)
	positions = unpack(positions)

	local values = calculate_noise(surface, positions)
	local dict = values.ms_tile_dictionary_nauvis
	local richness = values.ms_ore_richness_nauvis

	local tiles = {}
	local water_tiles = {}
	local reward_tiles = {}

	for i, position in ipairs(positions) do
		local name = TILES_MAP[dict[i]] or DEFAULT_TILE
		tiles[i] = { name = name, position = position }

		if dict[i] == 1 then
			water_tiles[#water_tiles+1] = position
		elseif rewards[math_floor(i/4)] then
			local ore_group = dict[i] < 5 and SAND_ORES or GRASS_ORES
			local name = ore_group[math_random(#ore_group)]
			if RICHNESS[name] > 0 then
				reward_tiles[#reward_tiles+1] = {
					name = name,
					position = { x = position.x, y = position.y },
					amount = richness[i] + RICHNESS[name] + 200 * math_max(math_abs(position.x), math_abs(position.y))
				}
			else
				for x = -1, 0 do
					for y = -1, 0 do
						reward_tiles[#reward_tiles+1] = {
							name = name,
							position = { x = position.x + x, y = position.y + y },
							amount = richness[i + x + y * 2]
						}
					end
				end
			end
		end
	end

	surface.set_tiles(tiles, true)
	local create_entity = surface.create_entity

	-- Add fish
	for _, position in ipairs(water_tiles) do
		if math_random(1, 16) == 1 then
			create_entity{ name = 'fish', position = position }
		end
	end

	-- Add ores
	for _, r in ipairs(reward_tiles) do
		create_entity{ name = r.name, position = r.position, amount = r.amount }
	end
end

---------------------------------------------------------
-- EFFECTS
---------------------------------------------------------

---@param surface LuaSurface
---@param position MapPosition
---@param player_index number
function Terrain.explosion(surface, position, player_index)
	local cause

	if surface.count_entities_filtered{ name = EXPLOSIONS, radius = 6, limit = 1 } == 0 then
		cause = surface.create_entity{
			name = 'atomic-rocket',
			position = { position.x + 1, position.y + 1 },
			target = { position.x + 1, position.y + 1 },
			speed = 1,
			force = FORCE_NAME,
		}
	end

	local player = game.get_player(player_index)
	if player and player.valid then
		if player.character and player.character.valid then
			player.character.die(FORCE_NAME, cause)
		end
	end
end

---@param surface LuaSurface
---@param position MapPosition
function Terrain.buried_nest(surface, position)
	surface.create_entity{
		name = 'minesweeper-buried-nest',
		position = { position.x + 1, position.y + 1 },
	}
end

---------------------------------------------------------
-- EVENT HANDLERS
---------------------------------------------------------

local function on_chunk_generated(event)
    local surface = event.surface
    local chunkpos = event.position
    local values = calculate_noise_chunk(surface, chunkpos, properties)

    local tiles = {}
	local water_tiles = {}
    local X, Y = chunkpos.x * 32, chunkpos.y * 32
    local i = 1
    for x = 0, 31 do
        for y = 0, 31 do
            local name = TILES_MAP[values[i]] or DEFAULT_TILE
			local position = { x = X+x, y = Y+y }
            tiles[i] = { name = name, position = position }
            i = i + 1

			if name == 'water-shallow' then
				water_tiles[#water_tiles+1] = position
			end
        end
    end

    surface.set_tiles(tiles, true)
    surface.regenerate_decorative(nil, { event.position })

	-- Add fish
	for _, position in pairs(water_tiles) do
		if math_random(1, 16) == 1 then
			surface.create_entity{ name = 'fish', position = position }
		end
	end
end

local function on_player_died(event)
	local cause = event.cause
	if not (cause and cause.valid) then
		return
	end

	local force = cause.force
	if not (force and force.name == FORCE_NAME) then
		return
	end

	local p = cause.position
	local search_positions = {}
	do
		for x = -4, 4 do
			for y = -4, 4 do
				search_positions[#search_positions+1] = { x = p.x + x, y = p.y + y }
			end
		end
	end

	Terrain.reveal_tiles(cause.surface, search_positions, {})
end

local function on_script_trigger_effect(event)
	if not event.effect_id == UNIT_SPAWNER_ID then
		return
	end
	
	if event.surface_index ~= SURFACE_INDEX then
		return
	end

	local entity = event.source_entity
    if not (entity and entity.valid) then
        return
    end

	local evo = math.ceil(game.forces.enemy.get_evolution_factor(entity.surface) * 100)

	entity.surface.create_entity {
		name = entity.name .. '-evolution-'..tostring(evo),
		position = entity.position,
		force = 'enemy',
	}
end

---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

Terrain.events = {
	[defines.events.on_script_trigger_effect] = on_script_trigger_effect
	--[defines.events.on_chunk_generated] = on_chunk_generated,
}

return Terrain
