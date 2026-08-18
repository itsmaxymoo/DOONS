pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- DOONS
-- by Max Loiacono

-- ------ THE FOLLOWING FILE IS UNDER THE CC BY-NC-SA 4.0 License:

-- cart storage: 0 = last selected difficulty; 1 = theme; 2 = swap pri/sec; 3 = anim speed; 7 - all time doons; 8+ = high score foreach difficulty

-- #region Pico8 Helpers

INT_MAX = 32767
PI = 3.1415926
HALF_PI = PI / 2
TAU = 6.2831853
DELTA = 1 / 60

function us(s)
	return unpack(split(s))
end

function tan(a)
	return sin(a) / cos(a)
end

function dgetd(i, d)
	local v = dget(i)
	return v != 0 and v or d
end

-- #endregion

-- #region State Machine

State = {}
State.__index = State

function State.new(init, update, draw, transparent_update, transparent_draw)
	return setmetatable(
		{
			init = init,
			update = update,
			draw = draw,
			transparent_update = transparent_update,
			transparent_draw = transparent_draw
		}, State
	)
end

_sm_state = {}

function sm_push(state, params, on_pop)
	add(_sm_state, { state = state, on_pop = on_pop })
	state:init(params)
end

function sm_pop(result)
	local entry = _sm_state[#_sm_state]
	del(_sm_state, entry)
	if entry.on_pop then
		entry.on_pop(result)
	end
end

function sm_reset(state, params)
	_sm_state = {}
	sm_push(state, params)
end

function sm_update()
	for i = #_sm_state, 1, -1 do
		if i == 1 or not _sm_state[i].state.transparent_update then
			for j = i, #_sm_state do
				_sm_state[j].state:update()
			end
			break
		end
	end
end

function sm_draw()
	for i = #_sm_state, 1, -1 do
		if i == 1 or not _sm_state[i].state.transparent_draw then
			for j = i, #_sm_state do
				_sm_state[j].state:draw()
			end
			break
		end
	end
end

-- #endregion

-- #region Input Manager

poke(0x5f2d, 0x1)
BTN_PRIMARY, BTN_SECONDARY, BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT, LMB, MMB, RMB = us "4,5,2,3,0,1,1,2,4"
BTN_GLYPHS = split "🅾️,❎,⬆️,⬇️,⬅️,➡️"
mouse_dx, mouse_dy, last_mouse, last_btn, mouse_down, mouse_up, mouse_x, mouse_y, prev_mouse_x, prev_mouse_y, mouse_just_down, _drag_start, drag_duration = us "0,0,0,0,0,0,0,0,0,0,0,0,0"
click_drag_start_x, click_drag_start_y, click_drag_end_x, click_drag_end_y = nil

function im_update()
	prev_mouse_x, prev_mouse_y, mouse_x, mouse_y, t, prev_mouse_down, mouse_down = mouse_x, mouse_y, stat(32), stat(33), time(), mouse_down, stat(34)
	mouse_up = prev_mouse_down & ~mouse_down
	mouse_just_down = ~prev_mouse_down & mouse_down

	if click_drag_end_x != nil then
		click_drag_start_x, click_drag_start_y, click_drag_end_x, click_drag_end_y = nil
	end
	if mouse_just_down & LMB > 0 then
		click_drag_start_x, click_drag_start_y, _drag_start = mouse_x, mouse_y, t
	end
	if mouse_up & LMB > 0 then
		click_drag_end_x, click_drag_end_y, drag_duration = mouse_x, mouse_y, t - _drag_start
	end

	mouse_dx, mouse_dy = mouse_x - prev_mouse_x, mouse_y - prev_mouse_y

	if mouse_down != 0 or mouse_up != 0 or mouse_dx != 0 or mouse_dy != 0 then
		last_mouse = t
	end

	if abs(last_mouse) <= 0.0667 then last_mouse = 0 end

	for b = 0, 5 do
		if btn(b) then last_btn = t end
	end
end

-- #endregion

-- #region UI Widgets

UI_PRIMARY_COLOR = 7
UI_SECONDARY_COLOR = 6
UI_BACKGROUND_COLOR = 0

function uiw_panel(x1, y1, x2, y2, pc, bg)
	rectfill(x1 - 1, y1 - 1, x2 + 1, y2 + 1, bg or UI_BACKGROUND_COLOR)
	rectfill(x1, y1, x2, y2, pc or UI_PRIMARY_COLOR)
	rectfill(x1 + 1, y1 + 1, x2 - 1, y2 - 1, bg or UI_BACKGROUND_COLOR)
end

UIWidget = {}
UIWidget.__index = UIWidget

function UIWidget.new(x, y, h, w)
	return setmetatable(
		{
			x = x,
			y = y,
			h = h,
			w = w,
			focused = false,
			clicked = false,
			neighbor_up = nil,
			neighbor_down = nil,
			neighbor_left = nil,
			neighbor_right = nil
		}, UIWidget
	)
end

function UIWidget:update()
	self.clicked = false
	if self.focused then
		if btnp(BTN_PRIMARY) then
			self.clicked = true
		elseif self.neighbor_up and btnp(BTN_UP) then
			self.neighbor_up.focused = true
			self.focused = false
		elseif self.neighbor_down and btnp(BTN_DOWN) then
			self.neighbor_down.focused = true
			self.focused = false
		elseif self.neighbor_left and btnp(BTN_LEFT) then
			self.neighbor_left.focused = true
			self.focused = false
		elseif self.neighbor_right and btnp(BTN_RIGHT) then
			self.neighbor_right.focused = true
			self.focused = false
		end
	end

	if click_drag_end_x != nil and click_drag_start_x != nil and click_drag_start_x >= self.x and click_drag_start_x <= self.x + self.w and click_drag_start_y >= self.y and click_drag_start_y <= self.y + self.h and click_drag_end_x >= self.x and click_drag_end_x <= self.x + self.w and click_drag_end_y >= self.y and click_drag_end_y <= self.y + self.h then
		self.focused, self.clicked = true, true
	end
end

function UIWidget:draw() end

function uiw_update(uiws)
	for uiw in all(uiws) do
		if mouse_just_down > 0 then
			uiw.focused = false
		end

		fs = uiw.focused
		uiw:update()

		if fs != uiw.focused then
			return
		end
	end
end

function uiw_draw(uiws)
	for uiw in all(uiws) do
		uiw:draw()
	end
end

---------------------------------------------

UIButton = {}
UIButton.__index = UIButton
setmetatable(UIButton, { __index = UIWidget })

function UIButton.new(tx, ty, tw, label)
	local self = UIWidget.new(tx * 8, ty * 8, 8, tw * 8)
	setmetatable(self, UIButton)

	self.label = label

	return self
end

function UIButton:draw()
	uiw_panel(self.x - 1, self.y - 1, self.x + self.w + 1, self.y + self.h + 1, UI_PRIMARY_COLOR)

	if self.focused then
		spr(180, self.x - 9, self.y + 1)
		spr(180, self.x + self.w + 2, self.y + 1, 1, 1, true)
	end

	twp = #self.label * 4

	print(self.label, self.x + flr((self.w - twp) / 2) + 1, self.y + 2, UI_PRIMARY_COLOR)
end

UIComboBoxH = {}
UIComboBoxH.__index = UIComboBoxH
setmetatable(UIComboBoxH, { __index = UIWidget })

function UIComboBoxH.new(tx, ty, tw, options, selected)
	local self = UIWidget.new(tx * 8, ty * 8, 8, tw * 8)
	setmetatable(self, UIComboBoxH)

	self.options = options
	self.selected = selected != nil and selected or 1

	return self
end

function UIComboBoxH:update()
	self.clicked = false
	if self.focused then
		if btnp(BTN_PRIMARY) then
			self.clicked = true
		elseif self.neighbor_up and btnp(BTN_UP) then
			self.neighbor_up.focused = true
			self.focused = false
		elseif self.neighbor_down and btnp(BTN_DOWN) then
			self.neighbor_down.focused = true
			self.focused = false
		elseif btnp(BTN_RIGHT) then
			self.focused = true
			self.selected = min(#self.options, self.selected + 1)
		elseif btnp(BTN_LEFT) then
			self.focused = true
			self.selected = max(1, self.selected - 1)
		end
	end

	if click_drag_end_x != nil and click_drag_start_x != nil and click_drag_start_x >= self.x and click_drag_start_x <= self.x + self.w and click_drag_start_y >= self.y and click_drag_start_y <= self.y + self.h and click_drag_end_x >= self.x and click_drag_end_x <= self.x + self.w and click_drag_end_y >= self.y and click_drag_end_y <= self.y + self.h then
		self.focused, self.clicked = true, true
		self.selected += 1
		if self.selected > #self.options then
			self.selected = 1
		end
	end
end

function UIComboBoxH:draw()
	uiw_panel(self.x - 1, self.y - 1, self.x + self.w + 1, self.y + self.h + 1, UI_PRIMARY_COLOR)

	if self.focused and self.selected > 1 then
		spr(180, self.x - 9, self.y + 1, 1, 1, true)
	end
	if self.focused and self.selected < #self.options then
		spr(180, self.x + self.w + 2, self.y + 1, 1, 1)
	end

	label = self.options[self.selected].name
	twp = #label * 4

	print(label, self.x + flr((self.w - twp) / 2), self.y + 2, UI_PRIMARY_COLOR)
end

-- #endregion

-- #region Hex Grid

function hex_neighbor(grid, x, y, dir_x, dir_y)
	local nx
	if dir_y == 0 then
		nx = x + dir_x
	elseif y % 2 == 1 then
		-- odd (normal) row
		nx = x + min(0, dir_x)
	else
		-- even (offset) row
		nx = x + max(0, dir_x)
	end
	local ny = y + dir_y
	if ny < 1 or ny > #grid then return nil end
	if nx < 1 or nx > #grid[ny] then return nil end
	return grid[ny][nx]
end

-- offset coords to concrete rect coords
function hex_hex_to_rect(grid, cx, cy)
	return cy % 2 == 0 and cx - 0.5 or cx - 1, cy - 1
end

-- concrete rect coords to offset hex coords
function hex_rect_to_hex(grid, rx, ry)
	local cy = flr(ry) + 1
	if cy < 1 or cy > #grid then return nil, nil, nil end

	local cx
	if cy % 2 == 1 then
		cx = flr(rx) + 1
	else
		cx = flr(rx - 0.5) + 1
	end

	if cx < 1 or cx > #grid[cy] then return nil, nil, nil end
	return cx, cy, grid[cy][cx]
end

function hex_get_zigzag(grid, sx, sy, angle)
	local grid_rw = #grid[1]
	local result = {}
	local dir = angle > 0 and -1 or 1
	local la = (HALF_PI + angle) / TAU
	local dx, mx = cos(la)
	local dy, my = sin(la)

	while sy > 0.5 do
		-- Find next cell intersection
		local b_x = dx > 0 and flr(sx * 2) * 0.5 + 0.5 or -flr(-sx * 2) * 0.5 - 0.5
		local b_y = dy > 0 and flr(sy * 2) * 0.5 + 0.5 or -flr(-sy * 2) * 0.5 - 0.5

		-- Distance to boundary
		local tx = dx != 0 and (b_x - sx) / dx or INT_MAX
		local ty = dy != 0 and (b_y - sy) / dy or INT_MAX

		-- Select first intersection
		local t = min(tx, ty)
		local nx = sx + dx * t
		local ny = sy + dy * t

		-- Snap to grid lines
		if t == tx then nx = b_x end
		if t == ty then ny = b_y end

		-- Get distance
		lmx = sx + dx * (t / 2)
		lmy = sy + dy * (t / 2)
		local cx, cy, cell = hex_rect_to_hex(grid, lmx, lmy)

		-- Determine if collision
		if cell != nil and next(cell) != nil then break end
		add(result, { sx, sy, nx, ny })
		mx, my = lmx, lmy
		if ny <= 0.5 then break end

		-- bounce
		if nx <= 0.5 then
			nx = 0.5
			dx = -dx
			dir = -dir
		elseif nx >= grid_rw then
			nx = grid_rw
			dx = -dx
			dir = -dir
		end

		sx, sy = nx, ny
	end

	last_cx, last_cy, last_cell = hex_rect_to_hex(grid, mx, my)
	add(result, { last_cx, last_cy })

	return result
end

function hex_get_disconnected_tiles(grid)
	local visited = {}
	local stack = {}
	local dirs = { { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

	-- Get tiles on first row
	if #grid >= 1 then
		for x = 1, #grid[1] do
			local cell = grid[1][x]
			if cell and next(cell) != nil then
				visited[x .. ",1"] = true
				add(stack, { x = x, y = 1 })
			end
		end
	end

	-- Get all tiles anchored to ceiling
	while #stack > 0 do
		local cell = stack[#stack]
		stack[#stack] = nil

		for d in all(dirs) do
			local dx, dy = d[1], d[2]
			local ny = cell.y + dy
			local nx

			-- Offset hex is a bad idea. Appears simple at first but god its annoying to work with.
			if dy == 0 then
				nx = cell.x + dx
			elseif cell.y % 2 == 1 then
				nx = cell.x + min(0, dx)
			else
				nx = cell.x + max(0, dx)
			end

			-- collect tiles
			local key = nx .. "," .. ny
			if not visited[key] then
				if ny >= 1 and ny <= #grid and nx >= 1 and nx <= #grid[ny] then
					local neighbor = grid[ny][nx]
					-- If the neighbor exists and contains a bubble/doon
					if next(neighbor) != nil and neighbor.doon != nil then
						visited[key] = true
						add(stack, { x = nx, y = ny })
					end
				end
			end
		end
	end

	-- get tiles not part of the ceiling connected set
	local disconnected = {}
	for y = 1, #grid do
		for x = 1, #grid[y] do
			local cell = grid[y][x]
			if cell and next(cell) != nil and cell.doon != nil then
				local key = x .. "," .. y
				if not visited[key] then
					add(disconnected, { x = x, y = y })
				end
			end
		end
	end

	return disconnected
end

-- #endregion

-- #region Doons Constants & Global Vars

cartdata("doons_f3bb5d380cba")
APP_VERSION = "1.0"
APP_TITLE, APP_AUTHOR, APP_URL = us "DOONS,Max Loiacono,AnthraciteSoftware.com"
tile_size, grid_fall, grid, grid_w, grid_h, grid_tx, grid_ty, grid_px, grid_py, shooter_x, shooter_y, box_px, box_py, box_ph, box_pw = 8, 0, nil
shooter_angle, drop_offset, drop_meter, drop_meter_anim_start, drop_meter_anim_t, score, all_time_doons, high_score = us "0,0,0,0,0,0,0,0"
SCORE_MULT = 10000
DROP_METER_GAIN = 0.4
DROP_METER_DRAIN = 0.1
shooter_path = nil
shooter_doons = {}
last_selected_difficulty = dgetd(0, 3)
ANIMATION_SPEED = 1
_doons = {}

DEATH_DOON = {
	-- skully
	spr = 116,
	no_shoot = true
}

ALL_DOONS = {
	{
		-- bluey
		spr = 64
		-- no_spawn = false,
		-- no_shoot = false,
	},
	{
		-- pointy
		spr = 80
	},
	{
		-- dummy
		spr = 96
	},
	{
		-- happy
		spr = 112
	},
	{
		-- angry
		spr = 68
	},
	{
		-- flakey
		spr = 84
	},
	{
		-- whiny
		spr = 100
	},
	DEATH_DOON
}

DIFFICULTY_OPTIONS = {
	{
		id = 1,
		name = "Zen: Huge",
		grid_h = 20,
		grid_w = 14,
		meter_gain = 0.0,
		meter_drain = 0.0,
		guide = true,
		drop_only_doons = true,
		doon_y = 15,
		doon_backlog = 3
	},
	{
		id = 2,
		name = "Zen: Large",
		grid_h = 16,
		grid_w = 11,
		meter_gain = 0.0,
		meter_drain = 0.0,
		guide = true,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 3
	},
	{
		id = 20,
		name = "Zen: Medium",
		grid_h = 15,
		grid_w = 9,
		meter_gain = 0.0,
		meter_drain = 0.0,
		guide = true,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 3
	},
	{
		id = 21,
		name = "Zen: Small",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.0,
		meter_drain = 0.0,
		guide = true,
		drop_only_doons = true,
		doon_y = 6,
		doon_backlog = 3
	},
	{
		id = 3,
		name = "Beginner",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.05,
		meter_drain = 0.15,
		guide = true,
		drop_only_doons = false,
		doon_y = 5,
		doon_backlog = 3
	},
	{
		id = 4,
		name = "Small",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.1,
		meter_drain = 0.15,
		guide = false,
		drop_only_doons = true,
		doon_y = 6,
		doon_backlog = 2
	},
	{
		id = 5,
		name = "Medium",
		grid_h = 15,
		grid_w = 9,
		meter_gain = 0.1,
		meter_drain = 0.15,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2
	},
	{
		id = 6,
		name = "Large",
		grid_h = 16,
		grid_w = 11,
		meter_gain = 0.1,
		meter_drain = 0.15,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2
	},
	{
		id = 7,
		name = "Huge",
		grid_h = 16,
		grid_w = 14,
		meter_gain = 0.1,
		meter_drain = 0.15,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2
	},
	{
		id = 8,
		name = "Hard: Small",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.15,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 7,
		doon_backlog = 2
	},
	{
		id = 9,
		name = "Hard: Medium",
		grid_h = 15,
		grid_w = 9,
		meter_gain = 0.15,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2
	},
	{
		id = 10,
		name = "Hard: Large",
		grid_h = 16,
		grid_w = 11,
		meter_gain = 0.15,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2
	},
	{
		id = 11,
		name = "Hard: Huge",
		grid_h = 16,
		grid_w = 14,
		meter_gain = 0.13,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 12,
		doon_backlog = 2
	},
	{
		id = 12,
		name = "Punishing: Small",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.06,
		meter_drain = 0,
		guide = false,
		drop_only_doons = true,
		doon_y = 6,
		doon_backlog = 3
	},
	{
		id = 13,
		name = "Punishing: Medium",
		grid_h = 15,
		grid_w = 9,
		meter_gain = 0.06,
		meter_drain = 0,
		guide = false,
		drop_only_doons = true,
		doon_y = 9,
		doon_backlog = 3
	},
	{
		id = 14,
		name = "Punishing: Large",
		grid_h = 16,
		grid_w = 11,
		meter_gain = 0.05,
		meter_drain = 0,
		guide = false,
		drop_only_doons = true,
		doon_y = 9,
		doon_backlog = 3
	},
	{
		id = 15,
		name = "Punishing: Huge",
		grid_h = 16,
		grid_w = 14,
		meter_gain = 0.04,
		meter_drain = 0,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 3
	},
	{
		id = 16,
		name = "Brutal: Small",
		grid_h = 12,
		grid_w = 6,
		meter_gain = 0.125,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 6,
		doon_backlog = 2,
		auto_shoot = 1
	},
	{
		id = 17,
		name = "Brutal: Medium",
		grid_h = 15,
		grid_w = 9,
		meter_gain = 0.125,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 8,
		doon_backlog = 2,
		auto_shoot = 1
	},
	{
		id = 18,
		name = "Brutal: Large",
		grid_h = 16,
		grid_w = 11,
		meter_gain = 0.125,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 8,
		doon_backlog = 2,
		auto_shoot = 1
	},
	{
		id = 19,
		name = "Brutal: Huge",
		grid_h = 16,
		grid_w = 14,
		meter_gain = 0.13,
		meter_drain = 0.1,
		guide = false,
		drop_only_doons = true,
		doon_y = 10,
		doon_backlog = 2,
		auto_shoot = 1
	}
}
DIFFICULTY = 5

-- #endregion

-- #region Helper functions

function sigmoid(t)
	return 1.01357 * (1 / (1 + 2.71828 ^ (-10 * t + 5)) - 0.006693)
end

function get_high_score(d)
	return dgetd(7 + DIFFICULTY_OPTIONS[d].id, 0)
end

function set_high_score(d, score)
	high_score = score
	dset(7 + DIFFICULTY_OPTIONS[d].id, score)
end

function calc_shooter_path()
	shooter_path = hex_get_zigzag(grid, (shooter_x - grid_px) / tile_size, (shooter_y - grid_py) / tile_size, shooter_angle)
end

function calc_death()
	for y = grid_h - (1 + drop_offset), grid_h do
		for x = 1, grid_w do
			if next(grid[y][x]) != nil then
				return true
			end
		end
	end

	return false
end

function calc_win()
	for y = 1, grid_h do
		for x = 1, grid_w do
			if next(grid[y][x]) != nil then
				return false
			end
		end
	end

	return true
end

function calc_mouse_in_box()
	if click_drag_start_x != nil and click_drag_start_x >= box_px and click_drag_start_x <= box_px + grid_w * tile_size + tile_size / 2 and click_drag_start_y >= box_py and click_drag_start_y <= box_py + grid_h * tile_size then
		return mouse_down, mouse_dx
	else
		return 0, 0
	end
end

function set_drop_meter(v)
	drop_meter_anim_start = min(drop_meter, 1)
	drop_meter = v
	drop_meter_anim_t = 0
end

function create_doon(i)
	if i == nil then
		i = flr(rnd(#ALL_DOONS)) + 1
	end

	d = {
		doon = ALL_DOONS[i],
		state = 1,
		last = 0
	}

	add(_doons, d)
	return d
end

function create_shooter_doons(n)
	n = n == nil and 1 or n

	valid_set = {}
	for i = 1, #ALL_DOONS do
		if not ALL_DOONS[i].no_shoot then
			add(valid_set, i)
		end
	end

	local top_row_one_type = nil
	for i in all(grid[1]) do
		if next(i) != nil then
			top_row_one_type = i.doon
			break
		end
	end
	for i in all(grid[1]) do
		if next(i) != nil and i.doon != top_row_one_type then
			top_row_one_type = nil
			break
		end
	end
	local top_row_one_type_can_shoot = 0
	for i = 1, #valid_set do
		if ALL_DOONS[valid_set[i]] == top_row_one_type then
			top_row_one_type_can_shoot = i
			break
		end
	end

	if top_row_one_type != nil and rnd() <= 0.34 and top_row_one_type_can_shoot > 0 and n == 1 then
		d = create_doon(top_row_one_type_can_shoot)
		add(shooter_doons, d)
	else
		for i = 1, n do
			sel = flr(rnd(#valid_set)) + 1
			d = create_doon(valid_set[sel])
			add(shooter_doons, d)
		end
	end
end

function remove_doon(d)
	del(_doons, d)
end

function get_matching_neighboring_doons(x, y, val)
	local result = {}
	local visited = {}
	local stack = {}
	local dirs = { { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

	visited[x .. "," .. y] = true
	add(stack, { x = x, y = y })
	add(result, { x = x, y = y })

	while #stack > 0 do
		local cell = stack[#stack]
		stack[#stack] = nil
		for d in all(dirs) do
			local dx, dy = d[1], d[2]
			local ny = cell.y + dy
			local nx
			if dy == 0 then
				nx = cell.x + dx
			elseif cell.y % 2 == 1 then
				nx = cell.x + min(0, dx)
			else
				nx = cell.x + max(0, dx)
			end
			local key = nx .. "," .. ny
			if not visited[key] then
				visited[key] = true
				local in_bounds = ny >= 1 and ny <= #grid
						and nx >= 1 and nx <= #grid[ny]
				if in_bounds and val != nil and next(grid[ny][nx]) != nil and grid[ny][nx].doon == val then
					add(result, { x = nx, y = ny })
					add(stack, { x = nx, y = ny })
				end
			end
		end
	end
	return result
end

function update_doons()
	for d in all(_doons) do
		p_switch = 0
		local l = d.last / 8

		if d.state == 0 then
			if l < 1 then
				p_switch = 0.00034
			elseif l < 2 then
				p_switch = 0.0007
			elseif l < 3 then
				p_switch = 0.002
			elseif l < 5 then
				p_switch = 0.007
			elseif p_switch < 6 then
				p_switch = 0.011
			elseif p_switch < 7 then
				p_switch = 0.03
			elseif p_switch < 8 then
				p_switch = 0.06
			elseif p_switch < 9 then
				p_switch = 0.125
			elseif p_switch < 10 then
				p_switch = 0.25
			elseif p_switch < 11 then
				p_switch = 0.5
			else
				p_switch = 0.8
			end
		elseif d.state == 1 then
			if l < 1 then
				p_switch = 0.015
			elseif l < 2 then
				p_switch = 0.007
			elseif p_switch < 3 then
				p_switch = 0.03125
			elseif p_switch < 4 then
				p_switch = 0.125
			elseif p_switch < 5 then
				p_switch = 0.25
			elseif p_switch < 6 then
				p_switch = 0.50
			elseif p_switch < 6.5 then
				p_switch = 0.707
			else
				p_switch = 0.9
			end
		end

		if rnd() < p_switch then
			d.state = 1 - d.state
			d.last = 0
		else
			d.last += DELTA
		end
	end
end

function update_shooter()
	MAX_ANGLE = HALF_PI - 0.1
	MIN_ANGLE = -1 * MAX_ANGLE

	rot_speed = 0.020
	if DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot then rot_speed *= 2 end
	mbd, mdx = calc_mouse_in_box()

	if btn(BTN_SECONDARY or (mbd & RMB > 0)) then
		rot_speed /= 8
	end

	if mbd == 0 then
		if btn(BTN_LEFT) then
			shooter_angle = min(shooter_angle + rot_speed, MAX_ANGLE)
			calc_shooter_path()
		end
		if btn(BTN_RIGHT) then
			shooter_angle = max(shooter_angle - rot_speed, MIN_ANGLE)
			calc_shooter_path()
		end
	else
		_shooter_angle = mid(MIN_ANGLE, shooter_angle - rot_speed * mdx * 0.8, MAX_ANGLE)
		if _shooter_angle != shooter_angle then
			shooter_angle = _shooter_angle
			calc_shooter_path()
		end
	end
end

function draw_playing_area_box()
	local base_w = grid_w * tile_size
	local play_h = grid_h * tile_size
	local frame_x2 = box_px + box_pw
	local frame_y2 = box_py + box_ph
	local r2 = box_py + (grid_h - 2) * tile_size

	-- Interior background
	rectfill(box_px, box_py, frame_x2 + tile_size / 2, frame_y2 - 1, 0)

	-- Interior lower limit line
	for px = box_px, frame_x2 - 8, 8 do
		spr(163, px, r2)
	end

	-- Drop ceiling
	clip(box_px - 3, box_py - 3, box_pw + 10, box_ph + 10)
	for i = drop_offset, 1, -1 do
		local t1, t2 = 131, 132
		if i == 1 then
			t1, t2 = 147, 148
		end

		local y = grid_py - (i - 1) * 8 - 8
		for px = box_px, frame_x2 - 8, 8 do
			spr(t1, px, y)
		end
		spr(t2, frame_x2, y)
	end
	clip()

	-- Top edge
	spr(128, box_px - 8, box_py - 8)
	for px = box_px, frame_x2 - 8, 8 do
		spr(129, px, box_py - 8)
	end
	spr(177, frame_x2, box_py - 8)

	-- Left/right edges (draw standard walls first)
	for py = box_py, frame_y2 - 8, 8 do
		spr(144, box_px - 8, py)
		spr(176, frame_x2, py)
	end

	-- letterbox
	rectfill(box_px - 1, box_py - 1, grid_px - 1, frame_y2, UI_PRIMARY_COLOR)
	rectfill(base_w + grid_px + tile_size / 2, box_py - 1, frame_x2 + 4, frame_y2, UI_PRIMARY_COLOR)

	-- dotted line spr
	if base_w != 84 then
		spr(164, frame_x2, r2)
	end

	-- Bottom edge
	if frame_y2 < 128 then
		spr(160, box_px - 8, frame_y2)
		for px = box_px, frame_x2 - 8, 8 do
			spr(161, px, frame_y2)
		end
		spr(178, frame_x2, frame_y2)
	end
end

function draw_path()
	if not DIFFICULTY_OPTIONS[DIFFICULTY].guide then return end
	for i = 1, #shooter_path - 1 do
		local seg = shooter_path[i]
		line(grid_px + seg[1] * tile_size, grid_py + seg[2] * tile_size, grid_px + seg[3] * tile_size, grid_py + seg[4] * tile_size, 10)
		--line(grid_px+seg[1]*tile_size-1, grid_py+seg[2]*tile_size, grid_px+seg[3]*tile_size-1, grid_py+seg[4]*tile_size, 10)
	end

	px, py = hex_hex_to_rect(grid, shooter_path[#shooter_path][1], shooter_path[#shooter_path][2])
	spr(tile_size == 8 and 134 or 150, px * tile_size + grid_px, py * tile_size + grid_py)
end

function draw_shooter()
	-- source: 16x24 sprite at sheet 112,72; rotation center is
	-- the pixel intersection at 120,88 -> (8,16) inside the sprite.
	local ssx, ssy = 112, 72
	local sw, sh = 16, 24
	local cx, cy = 8, 16
	-- shooter_angle=0 -> straight up; + rotates left, - rotates right.
	local a = -shooter_angle / TAU
	local sa, ca = sin(a), cos(a)
	-- center (8,16) -> furthest corner ~18px away
	for ox = -18, 18 do
		for oy = -18, 18 do
			local srcx = flr(ox * ca - oy * sa + cx)
			local srcy = flr(ox * sa + oy * ca + cy)
			if srcx >= 0 and srcx < sw and srcy >= 0 and srcy < sh then
				local c = sget(ssx + srcx, ssy + srcy)
				if c != 0 then
					pset(shooter_x + ox, shooter_y + oy, c)
				end
			end
		end
	end
end

function draw_doon(d, x, y, rot, force_large)
	if not d.doon then return end

	if tile_size == 8 or force_large then
		spr(d.doon.spr + d.state, x, y)
	else
		spr(d.doon.spr + d.state + 2, x, y)
	end
end

function draw_grid_doons()
	for x = 1, grid_w do
		for y = 1, grid_h do
			rx, ry = hex_hex_to_rect(grid, x, y)
			px, py = rx * tile_size + grid_px, ry * tile_size + grid_py
			draw_doon(grid[y][x], px, py)
		end
	end
end

function draw_mouse()
	if last_mouse > last_btn then
		spr(16, mouse_x, mouse_y)
	end
end

function draw_score(val, x, y, c)
	local s = ""
	hi = flr(val)
	lo = flr((val - hi) * SCORE_MULT + 0.5)

	if hi > 0 then
		s = hi
	end

	los = tostr(lo)
	while #los < 4 do
		los = "0" .. los
	end

	s = s .. los

	while #s < 9 do
		s = "0" .. s
	end

	print(s, x, y, c)
end

function draw_info_panel(idle_state)
	-- 1. Upcoming doons
	draw_doon(shooter_doons[1], shooter_x + 8, shooter_y - 4, 0, true)
	if #shooter_doons > 1 then
		print("2ND", 98, 18, 7)
		for i = 2, #shooter_doons do
			local d = shooter_doons[i]
			draw_doon(d, 111, 17 + 12 * (i - 2), 0, true)
		end
	end

	-- 2. Drop Meter
	dm_x = 98
	dm_y1 = 85
	dm_y2 = 26
	local ev
	if drop_meter == drop_meter_anim_start then
		ev = drop_meter
	else
		ev = drop_meter_anim_start + sigmoid(drop_meter_anim_t) * (min(1, drop_meter) - drop_meter_anim_start)
	end
	if ev > 0 then
		rectfill(dm_x, max(dm_y2, dm_y1 - (ev * (dm_y1 - dm_y2))), dm_x + 3, dm_y1, 8)
	end
	if ev == drop_meter then
		drop_meter_anim_start = drop_meter
	end

	drop_meter_anim_t = min(1, drop_meter_anim_t + 0.1)
	print("R\nO\nO\nF", 104, 44, 7)

	-- 3. Score
	uiw_panel(80, 116, 122, 124)
	draw_score(score, 84, 118, (score < high_score or score == 0) and UI_PRIMARY_COLOR or 12)

	-- 5. panel
	if grid_w == 11 or grid_w == 14 then
		line(95, 15, 95, 106, pget(94, 64))
	end

	-- 6. auto shoot meter
	if DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot then
		idle_state = idle_state and idle_state or {t_auto_shoot = 0, t_auto_shoot_max = 1}
		if idle_state.t_auto_shoot > 0 then
			rectfill(114, 85 - (idle_state.t_auto_shoot / idle_state.t_auto_shoot_max)*(85-27), 117, 85, 8)
		end
		rect(113, 26, 118, 86, UI_PRIMARY_COLOR)
	else
		-- 4. Shoot Button
		uiw_panel(97, 89, 118, 102, 8)
		print("FIRE", 100, 93, 8)
	end
end

-- #endregion

-- #region State Logic

STATE_PLAY_GAME_END = State.new(
	function(self, win)
		self.win = win
		self.highscore = false
		self.btn_again = UIButton.new(5, 10, 6, "PLAY AGAIN")
		self.btn_exit = UIButton.new(5, 12, 6, "QUIT")
		self.btn_again.focused = true
		self.btn_again.neighbor_down = self.btn_exit
		self.btn_exit.neighbor_up = self.btn_again
		self.uiws = { self.btn_exit, self.btn_again }
		self.hs = get_high_score(DIFFICULTY)

		if win then
			sfx(6)
			if score > self.hs then
				set_high_score(DIFFICULTY, score)
				self.highscore = true
			end
		end
	end,
	function(self)
		uiw_update(self.uiws)

		if self.btn_exit.clicked then
			sm_pop(false)
		elseif self.btn_again.clicked then
			sm_pop(true)
		end
	end,
	function(self)
		uiw_panel(28, 40, 100, 108)
		uiw_draw(self.uiws)
		if self.win then
			print("You won!", 50, 44, UI_PRIMARY_COLOR)
		else
			print("You lost!", 46, 44, UI_PRIMARY_COLOR)
		end

		print("Your Score:", 44, 51, UI_PRIMARY_COLOR)
		draw_score(score, 46, 60, (self.highscore and self.win) and 12 or UI_PRIMARY_COLOR)
		print("Best:", 36, 70, UI_SECONDARY_COLOR)
		draw_score((self.highscore and self.win) and score or self.hs, 58, 70, UI_SECONDARY_COLOR)
	end,
	false,
	true
)

STATE_PLAY_DEATH = State.new(
	function(self)
		self.t = 0
		self.row = 0
		sfx(3)

		for y = grid_h, 1, -1 do
			for x = 1, grid_w do
				if next(grid[y][x]) != nil then
					self.row = y
					return
				end
			end
		end
	end,
	function(self)
		update_doons()
		y = ceil(self.row - self.t)

		if y < 1 then
			sm_pop()
			return
		end

		for x = 1, grid_w do
			if grid[y][x].doon != nil then
				grid[y][x].doon = DEATH_DOON
			end
		end

		self.t += DELTA * 7 * ANIMATION_SPEED
	end,
	function() end,
	false,
	true
)

STATE_PLAY_LOWER_CEILING = State.new(
	function(self)
		self.t = 0
		self.ipy = grid_py
		self.npy = grid_py + tile_size
		drop_offset += 1
		set_drop_meter(0)
		sfx(7)
	end,
	function(self)
		if self.t < 1 then
			grid_py = self.ipy + tile_size * sigmoid(self.t)
			self.t += DELTA * 5 * ANIMATION_SPEED
		else
			grid_py = self.npy
			sm_pop()
		end

		update_doons()
	end,
	function()
		map(0, 0, 0, 0, 16, 16)
		x = box_px - 3
		y = box_py - 3
		draw_playing_area_box()
		draw_grid_doons()
		draw_shooter()
		draw_info_panel()
	end
)

STATE_PLAY_MATCH_AND_DROP = State.new(
	function(self, initial)
		self.drop_set = {}
		self.t = 0
		set = get_matching_neighboring_doons(initial[1], initial[2], grid[initial[2]][initial[1]].doon)

		drop = drop_meter + DROP_METER_GAIN

		if #set >= 3 then
			for c in all(set) do
				rx, ry = hex_hex_to_rect(grid, c.x, c.y)
				px, py = rx * tile_size + grid_px, ry * tile_size + grid_py
				add(self.drop_set, { grid[c.y][c.x], px, py })
				grid[c.y][c.x] = {}
			end

			disconnected = hex_get_disconnected_tiles(grid)
			if #disconnected > 0 then
				sfx(8)

				for c in all(disconnected) do
					rx, ry = hex_hex_to_rect(grid, c.x, c.y)
					px, py = rx * tile_size + grid_px, ry * tile_size + grid_py
					add(self.drop_set, { grid[c.y][c.x], px, py })
					grid[c.y][c.x] = {}
				end
			else
				sfx(5)
			end

			score += ((#self.drop_set) / 10 ) ^ 4 * 2

			drop = max(0, drop - DROP_METER_DRAIN * #self.drop_set)
			set_drop_meter(drop)
		else
			set_drop_meter(drop)
			sm_pop()
		end

		calc_shooter_path()
	end,
	function(self)
		self.t += DELTA * 25 * ANIMATION_SPEED
		update_shooter()
		update_doons()

		if self.t >= 15 then
			for d in all(self.drop_set) do
				remove_doon(d[1])
			end

			sm_pop()
		end
	end,
	function(self)
		y_offset = self.t ^ 2
		v_split = grid_w * tile_size / 2 + grid_px

		for d in all(self.drop_set) do
			draw_doon(d[1], d[2] + self.t * (d[2] > v_split and 1 or -1), flr(d[3] * 1.1) + y_offset)
		end
	end,
	false,
	true
)

STATE_PLAY_SHOOT = State.new(
	function(self, params)
		self.t = 0
		self.doon = shooter_doons[1]
		self.doon_x, self.doon_y = shooter_x - tile_size / 2, shooter_y - tile_size / 2
		self.done = false
		self.path = params.path
		self._dx = 0
		del(shooter_doons, self.doon)
		create_shooter_doons(1)
		all_time_doons = dgetd(7, 0) + (1 / SCORE_MULT)
		dset(7, all_time_doons)
		sfx(0)
	end,
	function(self)
		local found = false
		local accum = 0
		mx, my = nil

		for i = 1, #self.path - 1 do
			local seg = self.path[i]
			local x1, y1 = seg[1], seg[2]
			local x2, y2 = seg[3], seg[4]
			mx, my = (x1 + x2) / 2, (y1 + y2) / 2

			local dx = x2 - x1
			local dy = y2 - y1
			local len = sqrt(dx * dx + dy * dy)

			if self.t <= accum + len then
				local u = (self.t - accum) / len

				if (self._dx < 0 and dx > 0) or (self._dx > 0 and dx < 0) then
					sfx(1)
				end
				self._dx = dx

				self.doon_x = (x1 + dx * u) * tile_size - (tile_size / 2) + grid_px
				self.doon_y = (y1 + dy * u) * tile_size - (tile_size / 2) + grid_py

				found = true
				break
			end

			accum += len
		end

		if not found then
			-- end of path
			self.done = true
			grid_x, grid_y = hex_rect_to_hex(grid, mx, my)
			grid[grid_y][grid_x] = self.doon
			sfx(2)

			sm_push(
				STATE_PLAY_MATCH_AND_DROP, { grid_x, grid_y }, function(result)
					if drop_meter > 1 then
						sm_push(
							STATE_PLAY_LOWER_CEILING, nil, function(result)
								calc_shooter_path()
								sm_pop({ calc_death(), calc_win() })
							end
						)
					else
						sm_pop({ calc_death(), calc_win() })
					end
				end
			)
			return
		end

		self.t += DELTA * 30 * ANIMATION_SPEED
		update_shooter()
		update_doons()
	end,
	function(self)
		if not self.done then
			draw_doon(self.doon, self.doon_x, self.doon_y)
		end
	end,
	false,
	true
)

STATE_PLAY_QUIT = State.new(
	function(self)
		self.btn_no = UIButton.new(5, 9, 6, "NO")
		self.btn_yes = UIButton.new(5, 11, 6, "YES")
		self.btn_no.focused = true
		self.btn_yes.neighbor_up = self.btn_no
		self.btn_no.neighbor_down = self.btn_yes
		self.uiws = { self.btn_no, self.btn_yes }
	end,
	function(self)
		uiw_update(self.uiws)

		if self.btn_no.clicked or btnp(BTN_SECONDARY) then
			sm_pop(false)
		elseif self.btn_yes.clicked then
			sm_pop(true)
		end
	end,
	function(self)
		uiw_panel(28, 48, 100, 100)
		uiw_draw(self.uiws)
		print("Quit? Seriosuly?", 33, 56, 7)
	end,
	false,
	true
)

STATE_PLAY_IDLE = State.new(
	function(self)
		self.can_shoot = true
		self.locked = 1
		self.ui_shoot = UIWidget.new(96, 88, 112, 95)
		self.ui_quit_button = UIButton.new(14, 0.25, 1, "X")
		self.gameover = false
		self.t_auto_shoot = 0
		self.t_auto_shoot_max = DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot
		sfx(4)
	end,
	function(self)
		update_shooter()
		update_doons()
		self.ui_shoot:update()
		if last_mouse > last_btn then
			self.ui_quit_button:update()
			self.ui_quit_button.focused = false
		end

		if DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot then
			self.t_auto_shoot += DELTA
		end

		if self.locked <= 0 and self.can_shoot and ((DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot == nil and (btn(BTN_PRIMARY) or (mouse_x >= box_px and mouse_x <= box_px + grid_w * tile_size + tile_size / 2 and click_drag_end_x != nil and abs(click_drag_end_x - click_drag_start_x) + abs(click_drag_end_y - click_drag_start_y) == 0 and drag_duration <= 1) or self.ui_shoot.clicked)) or (DIFFICULTY_OPTIONS[DIFFICULTY].auto_shoot and self.t_auto_shoot >= self.t_auto_shoot_max)) then
			self.ui_shoot.clicked = false
			self.t_auto_shoot = 0
			sm_push(
				STATE_PLAY_SHOOT, { path = shooter_path }, function(params)
					local death = params[1]
					local win = params[2]
					if win or death then
						self.gameover = true
						handle_end_dialog = function(play_again)
							sm_pop()
							if play_again then
								sm_push(STATE_PLAY_INIT)
							end
						end
						if death then
							sm_push(
								STATE_PLAY_DEATH, nil, function()
									sm_push(STATE_PLAY_GAME_END, false, handle_end_dialog)
								end
							)
						elseif win then
							sm_push(STATE_PLAY_GAME_END, true, handle_end_dialog)
						end
						return
					end
				end
			)
			self.can_shoot = false
		elseif not btn(BTN_PRIMARY) then
			self.can_shoot = true
		end

		if btnp(BTN_DOWN) or self.ui_quit_button.clicked then
			sm_push(
				STATE_PLAY_QUIT, nil, function(quit)
					if quit then
						sm_pop()
					else
						self.locked = 1
					end
				end
			)
		end

		self.locked = max(0, self.locked - DELTA)
	end,
	function(self)
		map(0, 0, 0, 0, 16, 16)
		draw_playing_area_box()
		draw_grid_doons()
		if not self.gameover then
			draw_path()
		end
		draw_shooter()
		draw_info_panel(self)
		if last_mouse > last_btn then
			self.ui_quit_button:draw()
		end
	end
)

STATE_PLAY_INIT = State.new(function()
	local d = DIFFICULTY_OPTIONS[DIFFICULTY]
	grid_h, grid_w = d.grid_h, d.grid_w
	tile_size = (grid_h > 16 or grid_w > 11) and 6 or 8
	box_pw = flr((grid_w * tile_size + 7) / 8) * 8
	box_ph = flr((grid_h * tile_size + 7) / 8) * 8 + (tile_size == 6 and 8 or 0)
	box_px = flr((48 - box_pw / 2) / 8) * 8
	box_py = flr((68 - box_ph / 2) / 8) * 8
	grid_px = box_px + flr((box_pw - (grid_w * tile_size)) / 2)
	grid_py = box_py
	shooter_angle = 0
	drop_offset = 0
	drop_meter = 0
	score = 0
	_doons = {}
	shooter_doons = {}

	DROP_METER_DRAIN, DROP_METER_GAIN = d.meter_drain, d.meter_gain

	valid_top_row_doons = {}
	valid_doons = {}

	for i = 1, #ALL_DOONS do
		if not ALL_DOONS[i].no_shoot and not ALL_DOONS[i].no_top_row_spawn then
			add(valid_top_row_doons, i)
		end
		if not ALL_DOONS[i].no_spawn and not (ALL_DOONS[i].no_shoot and not d.drop_only_doons) then
			add(valid_doons, i)
		end
	end

	grid = {}
	for y = 1, grid_h do
		grid[y] = {}
		for x = 1, grid_w do
			grid[y][x] = {}

			if y <= d.doon_y and rnd() < 0.95 then
				-- spawn a random doon
				if y == 1 then
					sel = flr(rnd(#valid_top_row_doons)) + 1
					doon = create_doon(valid_top_row_doons[sel])
				else
					sel = flr(rnd(#valid_doons)) + 1
					doon = create_doon(valid_doons[sel])
				end

				grid[y][x] = doon
			end
		end
	end

	disconnected = hex_get_disconnected_tiles(grid)
	for _d in all(disconnected) do
		remove_doon(grid[_d.y][_d.x])
		grid[_d.y][_d.x] = {}
	end

	shooter_x = grid_px + grid_w * tile_size / 2 + tile_size / 4
	shooter_y = grid_py + grid_h * tile_size - tile_size
	calc_shooter_path()
	create_shooter_doons(d.doon_backlog)

	sm_pop()
	sm_push(STATE_PLAY_IDLE)
end)

STATE_SETTINGS = State.new(
	function(self)
		self.cb_theme = UIComboBoxH.new(
			3, 2, 10, {
				{
					name = "Doons",
					value = 1
				},
				{
					name = "Pastel",
					value = 2
				}
			}, dgetd(1, 1)
		)
		self.cb_primary = UIComboBoxH.new(
			3, 5, 10, {
				{
					name = "🅾️/❎ (z/x)",
					value = 1
				},
				{
					name = "❎/🅾️ (x/z)",
					value = 2
				}
			}, dgetd(2, 1)
		)
		self.cb_animations = UIComboBoxH.new(
			3, 8, 10, {
				{
					name = "Slow",
					value = 1
				},
				{
					name = "Normal",
					value = 2
				},
				{
					name = "Fast",
					value = 3
				}
			}, dgetd(3, 2)
		)

		self.btn_cancel = UIButton.new(3, 12, 5, "CANCEL")
		self.btn_cancel.focused = true
		self.btn_save = UIButton.new(9, 12, 4, "SAVE")

		self.cb_theme.neighbor_down = self.cb_primary
		self.cb_primary.neighbor_up = self.cb_theme
		self.cb_primary.neighbor_down = self.cb_animations
		self.cb_animations.neighbor_up = self.cb_primary
		self.cb_animations.neighbor_down = self.btn_cancel
		self.btn_cancel.neighbor_up = self.cb_animations
		self.btn_cancel.neighbor_right = self.btn_save
		self.btn_save.neighbor_left = self.btn_cancel
		self.btn_save.neighbor_up = self.cb_animations
		self.special = 0

		self.uiws = { self.cb_theme, self.cb_primary, self.cb_animations, self.btn_cancel, self.btn_save }
	end,
	function(self)
		uiw_update(self.uiws)

		if self.btn_save.focused and btnp(BTN_RIGHT) then
			self.special += 1
		elseif self.btn_save.focused and btnp(BTN_LEFT) then
			self.special -= 1
		end

		if self.btn_cancel.clicked or btnp(BTN_SECONDARY) then
			sm_pop(false)
		elseif self.btn_save.clicked then
			dset(1, self.cb_theme.options[self.cb_theme.selected].value)
			dset(2, self.cb_primary.options[self.cb_primary.selected].value)
			dset(3, self.cb_animations.options[self.cb_animations.selected].value)
			sm_pop(true)
		end
	end,
	function(self)
		if self.special != 10 then
			uiw_draw(self.uiws)
			print("Theme:", 24, 8, 7)
			print("Primary/secondary:", 24, 32, 7)
			print("Animation speed:", 24, 56, 7)
		else
			map(32, 0, 0, 0, 16, 16)
			print("by " .. APP_AUTHOR, 4, 98, 6)
			print("version " .. APP_VERSION, 4, 106, 6)
			print(APP_URL, 4, 114, 6)
		end
	end
)

STATE_TITLE = State.new(
	function(self)
		all_time_doons = dgetd(7, 0)
		self.btn_start = UIButton.new(3, 12, 10, "START")
		self.btn_start.focused = true
		self.btn_settings = UIButton.new(8, 14, 5, "SETTINGS")
		self.cb_difficulty = UIComboBoxH.new(3, 10, 10, DIFFICULTY_OPTIONS, DIFFICULTY)
		for i = 1, #DIFFICULTY_OPTIONS do
			if DIFFICULTY_OPTIONS[i].id == last_selected_difficulty then
				self.cb_difficulty.selected = i
				break
			end
		end
		high_score = get_high_score(self.cb_difficulty.selected)
		self.btn_quit = UIButton.new(3, 14, 4, "QUIT")
		self.btn_start.neighbor_down = self.btn_quit
		self.btn_start.neighbor_up = self.cb_difficulty
		self.cb_difficulty.neighbor_down = self.btn_start
		self.btn_settings.neighbor_up = self.btn_start
		self.btn_settings.neighbor_left = self.btn_quit
		self.btn_quit.neighbor_right = self.btn_settings
		self.btn_quit.neighbor_up = self.btn_start
		self.uiws = { self.cb_difficulty, self.btn_start, self.btn_settings, self.btn_quit }

		-- Game init - theme
		if dgetd(1, 1) == 2 then
			memcpy(0x1000, 0x1800, 0x0800)
			for a = 0x0800, 0x0e00, 0x0200 do
				for i = 0, 7 do
					memcpy(a + i * 0x40, a + 0x20 + i * 0x40, 0x20)
				end
			end
			UI_PRIMARY_COLOR = 5
			UI_SECONDARY_COLOR = 6
			UI_BACKGROUND_COLOR = 0
		else
			UI_PRIMARY_COLOR = 7
			UI_SECONDARY_COLOR = 6
			UI_BACKGROUND_COLOR = 0
		end
		-- Game init - primary buttons
		local o, x = BTN_PRIMARY, BTN_SECONDARY
		if dgetd(2, 1) == 1 then
			BTN_PRIMARY = o
			BTN_SECONDARY = x
		else
			BTN_PRIMARY = x
			BTN_SECONDARY = o
		end
		-- Game init - animation speed
		local speed_i = dgetd(3, 2)
		if speed_i == 1 then
			ANIMATION_SPEED = 0.7
		elseif speed_i == 2 then
			ANIMATION_SPEED = 1
		elseif speed_i == 3 then
			ANIMATION_SPEED = 2
		end
	end,
	function(self)
		uiw_update(self.uiws)

		if self.cb_difficulty.options[self.cb_difficulty.selected].id != last_selected_difficulty then
			last_selected_difficulty = self.cb_difficulty.options[self.cb_difficulty.selected].id
			high_score = get_high_score(self.cb_difficulty.selected)
			dset(0, last_selected_difficulty)
		end

		if self.btn_start.clicked then
			DIFFICULTY = self.cb_difficulty.selected
			sm_push(STATE_PLAY_INIT)
		elseif self.btn_quit.clicked then
			cls()
			extcmd("shutdown")
			stop()
		elseif self.btn_settings.clicked then
			sm_push(
				STATE_SETTINGS, nil, function(changes)
					if changes then
						reload()
						sm_pop()
					end
				end
			)
		end
	end,
	function(self)
		map(16, 0, 0, 0, 16, 16)
		uiw_draw(self.uiws)
		print("v" .. APP_VERSION, 108, 122, 5)
		draw_score(all_time_doons, 82, 58, UI_SECONDARY_COLOR)
		print("High Score:", 24, 71, UI_SECONDARY_COLOR)
		draw_score(high_score, 70, 71, UI_PRIMARY_COLOR)
	end
)

STATE_INIT = State.new(
	function(self) end,
	function(self)
		sm_push(STATE_TITLE)
	end,
	function(self) end
)

-- #endregion

-- #region Pico8 Loop

function _init()
	sm_push(STATE_INIT)
end

function _update60()
	im_update()
	uiw_update()
	sm_update()
end

function _draw()
	cls()
	sm_draw()
	uiw_draw()
	draw_mouse()
end

-- #endregion

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57775000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05566500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0cccccc00cccccc00cccc0000cccc000088888800888888008888000088880000011110000111100011110000111100048888884488888840488400004884000
ccccccccccccccccc0cc0c00c0cc0c00888888888888888880880800808808000111111001111110101101001011010084888848848888488144180081441800
c00cc00ccc0cc0cccccccc00cccccc00808888088088880888888800888888001771177117711771111111001122110081488418814884188888880088888800
c00cc00cc00cc00cc0000c00cc00cc00800880088008800888008800808808001701107117011071121121001255210081188118811881188822880088228800
cccccccccccccccccc00cc00cc00cc00888888888888888880880800880088001111111111222211112211001255210088888888888888888222280082ee2800
cc0000cccc0000cc0cccc0000cccc0008880088880888808088880000888800011211211112dd211011110000122100088822888882222880288200008228000
ccc00ccccc0000cc000000000000000088000088880000880000000000000000011221100112211000000000000000008822228882eeee280000000000000000
0cccccc00cccccc00000000000000000080880800880088000000000000000000011110000111100000000000000000008288280082222800000000000000000
000ee000000ee00000ee000000ee0000006006000060060006006000060060000002200000022000002200000022000060600606606006060600600006006000
000ee000000ee00000ee000000ee0000006006000060060060660600606606000202202002022020202202002022020006cccc6006cccc6067cc760067cc7600
00eeee0000eeee000eeee0000eeee00066066066660660660666600006006000002222000022220002222000022220006cfccfc66cfccfc601cc100001cc1000
00eeee0000eeee000eeee0000eeee00000666600006006000600600006006000007227000022220002222000022220000c1cc1c00c1cc1c007cc70000cccc000
0e0ee0e00e0ee0e0e0ee0e00e0ee0e0000600600006006006666660066666600070220700ed22de0e0220e00e0220e000cccccc00cccccc06c77c6006c77c600
0e0ee0e00e0ee0e0eeeeee00ee00ee0066666666666666660600600006006000022222200222222022222200226622006cfccfc66ccffcc60600600006006000
eeeeeeeeeee00eee0000000000000000006006000060060000000000000000002266662222666622000000000000000006cffc6006fccf600000000000000000
eee00eeeeee00eee0000000000000000006006000060060000000000000000002222222222222222000000000000000060600606606006060000000000000000
bbbbbbbbbbbbbbbbbbbbbb00bbbbbb0055500555555005555500550055005500bbbbbbbbbbbbbbbbbbbbbb00bbbbbb0057700775577007755500550055005500
b00bb00bb00bb00bb0bb0b00b0bb0b0050055005550550555055050050550500b77bb77bb77bb77b77bb770077bb770050755705570550755755750057557500
b00bb00bb00bb00bbbbbbb00bbbbbb0050055005500550050555500005555000b70bb07bb70bb07b70bb070070bb070005555550055555500555500005555000
bbbbbbbbbbbbbbbbbbbbbb00b0000b0005555550055555500500500005005000bbbbbbbbbbbbbbbbbbbbbb00bbbbbb0005555550055dd5500d55d00005dd5000
bbbbbbbbbbbbbbbbb0000b00b00bbb0005555550055005500555500005005000bbbbbbbbb888888bb8888b00b8888b0005d55d5005dddd5005dd50000d55d000
bb0000bbb000000bbbbbbb00bbbbbb0005000050050000500555500005555000bb8888bbb8beeb8bbbbbbb00beebbb0005dddd5005d55d500555500005555000
bbbbbbbbbb00bbbb000000000000000005500550050000500000000000000000bbbbbbbbb88ee88b0000000000000000055dd550055555500000000000000000
bbbbbbbbbbbbbbbb000000000000000000555500005555000000000000000000bbbbbbbbbbbeebbb000000000000000000555500005555000000000000000000
00aaaa0000aaaa000aaaa0000aaaa000077777700777777007777000077770000099990000999900099990000999900007777770077777700777700007777000
0aaaaaa00aaaaaa00000000000000000700770077877778770770700787787000999999009999990055550000555500075577557798778977577570079779700
0000000000000000aa0a0a00a0a0aa00700770077887788777777700777777000555555005555550995959009595990075077057798778977577570078778700
aa00a00aa00a00aaaaaaaa00aaaaaa00777777777777777707007000070070009955955999559559999999009999990077777777777777770777700007777000
aaaaaaaaaaaaaaaa0a0000000000a000777777777777777700770000000000009999999999999999098880000888900077777777777777770044000000440000
0a0000a00a0000a00aaaa0000aaaa000007007000070070000770000007700000988889009988890099990000999900000777700007777000077000000770000
0aa00aa00aa00aa00000000000000000007007000077770000000000000000000987789009989890000000000000000000744700007447000000000000000000
00aaaa0000aaaa000000000000000000007777000077770000000000000000000098880000988800000000000000000000777700007777000000000000000000
600000666000006660000066000660000006777600000000777777770000000000000000000000000000000000000000000000077000000077777777cccccccc
000006660000066600000666000660000006777607777770700000070000000000000000000000000000000000000000000000777700000077777777cccccccc
000066600000666000006660000660000006777007000070700000070000000000000000000000000000000000000000000007777770000077777777cccccccc
000666000006660000066600000660000006777007000070700000070000000000000000000000000000000000000000000077777777000077777777cccccccc
006660000066600000666000000660000006777007000070700000070000000000000000000000000000000000000000000777777777700077777777cccccccc
066607777777777777760000000660000006777007000070700000070000000000000000000000000000000000000000007777777777770077777777cccccccc
666007777777777777700000000660000006777007000070700000070000000000000000000000000000000000000000077777777777777077777777cccccccc
660007777777777777700006000660000006777607000070777777770000000000000000000000000000000000000000777777777777777777777777cccccccc
60000777600000667770006600066000000677760700007077777700000000000000000000000000000000000000000077777777777777770000000000000000
00000777000006667770066600066000000677760700007070000700000000000000000000000000000000000000000007777777777777700000000000000000
00006777000066607770666000066000000677700700007070000700000000000000000000000000000000000000000000777777777777000000000000000000
00066777000666007776660000066000000677700700007070000700000000000000000000000000000000000000000000077777777770000000000660000000
00666777006660007776600000066000000677700700007070000700000000000000000000000000000000000000000000007777777700000000000660000000
06660777066600007776000077777777777777700700007077777700000000000000000000000000000000000000000000000777777000000000000660000000
66600777666000007770000077777777777777700700007000000000000000000000000000000000000000000000000000000077770000000000000660000000
66000777660000067770000677777777777777760700007000000000000000000000000000000000000000000000000000000007700000000000006666000000
60000777777777777770006606600660066077760700007000000000000000000000000000000000000000000000000000000000000000000000006666000000
00000777777777777770066600000000000077760700007000000000000000000000000000000000000000000000000000000000000000000000006666000000
00006777777777777770666000000000000077700700007000000000000000000000000000000000000000000000000000000000000000000000066666600000
00066600000666000006660000000000000077700700007000000000000000000000000000000000000000000000000000000000000000000000067777600000
00666000006660000066600000000000000077700700007000000000000000000000000000000000000000000000000000000000000000000000777777770000
06660000066600000666000000000000000077700700007000000000000000000000000000000000000000000000000000000000000000000000777777770000
66600000666000006660000000000000000077700777777000000000000000000000000000000000000000000000000000000000000000000007777667777000
66000006660000066600000600000000000077760000000000000000000000000000000000000000000000000000000000000000000000000007776666777000
00007776600000667777777600007777000000000000000000000000000000000000000000000000000000000000000000000000000000000007776666777000
00007776000006667777777600007777000070000000000000000000000000000000000000000000000000000000000000000000000000000007777667777000
00007770000066607777777000007777000007000000000000000000000000000000000000000000000000000000000000000000000000000000777777770000
00007770000666000006660000007777000000700000000000000000000000000000000000000000000000000000000000000000000000000000777777770000
00007770006660000066600000007777000000700000000000000000000000000000000000000000000000000000000000000000000000000000007777000000
00007770777777700666000000007777000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007770777777706660000000007777000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007776777777766600000600007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666688888848888855560000000001111110000000000000000000000000000000000000000000000006600000006666666611111111
66666666666666666666666688888848888855560111111011000011000000000000000000000000000000000000000000000066660000006666666611111111
66666666666666666666666644444444444455560100001010000001000000000000000000000000000000000000000000000666666000006666666611111111
66666666666666666666666688488888884855560100001010000001000000000000000000000000000000000000000000006666666600006666666611111111
66666666666666666666666688488888884855560100001010000001000000000000000000000000000000000000000000066666666660006666666611111111
66666555555555555556666688488888884855560100001010000001000000000000000000000000000000000000000000666666666666006666666611111111
66666555555555555556666644444444444455560100001011000011000000000000000000000000000000000000000006666666666666606666666611111111
66666555555555555556666688888848888855560100001001111110000000000000000000000000000000000000000066666666666666666666666611111111
66666555666666665556666688888848888855560100001001111000000000000000000000000000000000000000000066666666666666660000000000000000
66666555666666665556666688888848888855560100001010000100000000000000000000000000000000000000000006666666666666600000000000000000
66666555666666665556666644444444444455560100001010000100000000000000000000000000000000000000000000666666666666000000000000000000
66666555666666665556666688488888884855560100001010000100000000000000000000000000000000000000000000066666666660000000000aa0000000
66666555666666665556666688488888884855560100001010000100000000000000000000000000000000000000000000006666666600000000000aa0000000
66666555666666665556666688488888884855560100001001111000000000000000000000000000000000000000000000000666666000000000000aa0000000
66666555666666665556666644444444444455560100001000000000000000000000000000000000000000000000000000000066660000000000000aa0000000
6666655566666666555666666666666666665556010000100000000000000000000000000000000000000000000000000000000660000000000000aaaa000000
6666655555555555555666660aa00aa00aa05556010000100000000000000000000000000000000000000000000000000000000000000000000000aaaa000000
6666655555555555555666660000000000005556010000100000000000000000000000000000000000000000000000000000000000000000000000aaaa000000
666665555555555555566666000000000000555601000010000000000000000000000000000000000000000000000000000000000000000000000aaaaaa00000
666666666666666666666666000000000000555601000010000000000000000000000000000000000000000000000000000000000000000000000a1111a00000
66666666666666666666666600000000000055560100001000000000000000000000000000000000000000000000000000000000000000000000111111110000
66666666666666666666666600000000000055560100001000000000000000000000000000000000000000000000000000000000000000000000111111110000
66666666666666666666666600000000000055560111111000000000000000000000000000000000000000000000000000000000000000000001111aa1111000
6666666666666666666666660000000000005556000000000000000000000000000000000000000000000000000000000000000000000000000111aaaa111000
0000555666666666555555560000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000111aaaa111000
00005556666666665555555600005555000060000000000000000000000000000000000000000000000000000000000000000000000000000001111aa1111000
00005556666666665555555600005555000006000000000000000000000000000000000000000000000000000000000000000000000000000000111111110000
00005556666666666666666600005555000000600000000000000000000000000000000000000000000000000000000000000000000000000000111111110000
00005556666666666666666600005555000000600000000000000000000000000000000000000000000000000000000000000000000000000000001111000000
00005556555555566666666600005555000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005556555555566666666600005555000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005556555555566666666600005555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000000000000000000000000000
777777777777777770000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777770000000000000000000000770000000
777777777777777777000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777000000000000000000007777000000
777777777777777777700000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777700000000000000000077777700000
777777777777777777770000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777770000000000000000777777770000
777777777777777777777000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777777000000000000007777777777000
777777777777777777777700cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777777700000000000077777777777700
777777777777777777777770cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777777770000000000777777777777770
777777777777777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777777777000000007777777777777777
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777700000007777777700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777770000000777777700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777000000077777700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777700000007777700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777770000000777700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777777000000077700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777777700000007700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777777777777777777770000000700000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000070000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077000000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077700000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077770000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077777000
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077777700
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077777770
777777770000000077777777cccccccc0000000000000000cccccccccccccccc0000000000000000cccccccc7777777700000000777777770000000077777777
777777777777777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777777777777777777777
777777777777777777777770cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770777777777777770
777777777777777777777700cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770077777777777700
777777777777777777777000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770007777777777000
777777777777777777770000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770000777777770000
777777777777777777700000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770000077777700000
777777777777777777000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770000007777000000
777777777777777770000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777777700000000777777770000000770000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000060000066000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000000000666000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000000006660000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000000066600000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000000666000000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000006660000000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000066600000000000000000000000000000
000000000000000000000000cccccccccccccccc00000000000000000000000000000000cccccccccccccccc0000000066000006000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000060000066000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000000000666000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000000006660000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000000066600000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000000666000000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000006660000000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000066600000000000000000000000000000
000000000000000000000000cccccccccccccccccccccccc0000000000000000cccccccccccccccccccccccc0000000066000006000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000060000066000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000666000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000006660000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000066600000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000666000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000006660000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000066600000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc000000000000000066000006000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000006660000066000000006000006600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066600000666000000000000066600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666000006660000000000000666000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006660000066600000000000006660000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066600000666000000000000066600000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666000006660000000000000666000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006660000066600000000000006660000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006600000666000006000000006600000600000000
00000000000000000000000000000000000000000000000000000000000000006000006660000066600000666000006600000000000000006000006600000000
00000000000000000000000000000000000000000000000000000000000000000000066600000666000006660000066600000000000000000000066600000000
00000000000000000000000000000000000000000000000000000000000000000000666000006660000066600000666000000000000000000000666000000000
00000000000000000000000000000000000000000000000000000000000000000006660000066600000666000006660000000000000000000006660000000000
00000000000000000000000000000000000000000000000000000000000000000066600000666000006660000066600000000000000000000066600000000000
00000000000000000000000000000000000000000000000000000000000000000666000006660000066600000666000000000000000000000666000000000000
00000000000000000000000000000000000000000000000000000000000000006660000066600000666000006660000000000000000000006660000000000000
00000000000000000000000000000000000000000000000000000000000000006600000666000006660000066600000600000000000000006600000600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000666000006600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006660000066600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066600000666000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666000006660000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006660000066600000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066600000666000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666000006660000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000066600000600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000006660000066600000660000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066600000666000006660000000000000000
00006660606000000000666060600000000006606660666006600660660006600000000000000000000000000000666000006660000066600000000000000000
00006060606000006660606060600000600060600600606060006060606060600000000000000000000000000006660000066600000666000000000000000000
00006600666000006660666006000000600060600600666060006060606060600000000000000000000000000066600000666000006660000000000000000000
00006060006000006060606060600000600060600600606060006060606060600000000000000000000000000666000006660000066600000000000000000000
00006660666000006060606060600000066066006660606006606600606066000000000000000000000000006660000066600000666000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006600000666000006660000060000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00006060666066600660666006606600000066000000666000000000000000000000000000000000000000000000000000000000000000000000000000006660
00006060600060606000060060606060000006000000606000000000000000000000000000000000000000000000000000000000000000000000000000066600
00006060660066006660060060606060000006000000606000000000000000000000000000000000000000000000000000000000000000000000000000666000
00006660600060600060060060606060000006000000606000000000000000000000000000000000000000000000000000000000000000000000000006660000
00000600666060606600666066006060000066600600666000000000000000000000000000000000000000000000000000000000000000000000000066600000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066000006
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000660066606060666066600660666066606660000006606660666060606660666066600000066006606660000000000000000000000000000000000000
00000660606006006060606060606000060006006000066060606000060060606060606060000000600060606660000000000000000000000000000000000000
00006060606006006660660066606000060006006600600060606600060060606660660066000000600060606060000000000000000000000000000000000000
00006660606006006060606060606000060006006000006060606000060066606060606060000000600060606060000000000000000000000000000000000000
00006060606006006060606060600660666006006660660066006000060066606060606066600600066066006060000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
91919191919191919191919191919191000000008f8f8f8f8f8f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919180818181828e8e8d8f8f8f8f8f8f8f8f8e8d008c8d000000008f8f8f8f8f8f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190000000928e008e8f00008f8f00008f8e8e8d9c008e8e8d8f8f8f8f8f8f8f8f8e8d008c8d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190850000928e008e8f00008f8f00008f8e008e008d8e008e8f00008f8f00008f8e8e8d9c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190950000928e8e9d8f8f8f8f8f8f8f8f8e008e9c9d8e008e8f00008f8f00008f8e008e008d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190950000920000008f8f000000008f8f00000000008e8e9d8f8f8f8f8f8f8f8f8e008e9c9d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190950000920000008f8f8f00008f8f8f00000000000000008f8f000000008f8f00910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
91919191919191919191919095000092000000008f8f8f8f8f8f0000000000000000008f8f8f00008f8f8f00910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191909500009200000000000000000000000000000000000000008f8f8f8f8f8f0000910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191909500009200000000000000000000000000000000000000000000000000000091910091000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919191919191919191919190a500009200000000000000000000000000000000000000000000000091919191000091000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191900000009200000000000000000000000000000000000000000000000000000000009191000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191900000009200000000000000000000000000000000000000000000000000000091919100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191a0a1a1a1a200000000000000000000000000000000000000000000000000000000000000910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191919191919100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9191919191919191919191919191919100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000008f0000000000000000000000000000008f0000000000000000000000000000008f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000085510c5510f55113551185511c5511e55100501005010170100701007010170100701007010050100501005010050100501005010050100501005010050100501005010050100501005010050100501
000100001655115551125510f5510d5510c5510b55100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501005010050100501
000a00001b723187130d7030c7030a70308703067030470303703027030e7030b70306703097030170306703057030870303703017030070302703037030a7030070300703007030070300703007030070300703
000d00002023120231202312023120231122311223112231122311223112231232312323123231232312323123231232212321123211232010020100201002010020100201002010020100201002010020100201
001000001a322123220b3220732205322043220432205322083220b3220e32214322183221f322263222732227312273122b5022c5022d3020000200002000020000200002000020000200002000020000200002
000400001e5521a55216552125520e552095522250222502225022250222502095020950209502095020950209502005020050200502005020050200502005020050200502005020050200502005020050200502
000c00001e5521e5521e5521a5521a552225522255222552225422055220552205521e5521e552275522755227552275522755227542275322752227515275020050200502005020050200502005020050200502
001000001032011320103200e32000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000500001e5521a55216552125520e55209552115520c552075520353201502095020950209502095020950209502005020050200502005020050200502005020050200502005020050200502005020050200502
