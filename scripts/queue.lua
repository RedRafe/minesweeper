---@class Queue
local Queue = {}
Queue.__index = Queue

script.register_metatable('Queue', Queue)

function Queue.new()
    return setmetatable({
        _head = 1,
        _tail = 1
    }, Queue)
end

---@param self Queue
function Queue:size()
    return self._head - self._tail
end

---@param self Queue
---@param element any
function Queue:push(element)
    local index = self._head
    self[index] = element
    self._head = index + 1
end

--- Pushes the element such that it would be the next element pop'ed.
---@param self Queue
---@param element any
function Queue:push_to_end(element)
    local index = self._tail - 1
    self[index] = element
    self._tail = index
end

---@param self Queue
function Queue:peek()
    return self[self._tail]
end

---@param self Queue
function Queue:peek_start()
    return self[self._head - 1]
end

---@param self Queue
---@param index number
function Queue:peek_index(index)
    return self[self._tail + index - 1]
end

---@param self Queue
function Queue:pop()
    local index = self._tail

    local element = self[index]
    self[index] = nil

    if element then
        self._tail = index + 1
    end

    return element
end

---@param self Queue
function Queue:to_array()
    local n = 1
    local res = {}

    for i = self._tail, self._head - 1 do
        res[n] = self[i]
        n = n + 1
    end

    return res
end

---@param self Queue
function Queue:pairs()
    local index = self._tail
    return function()
        local element = self[index]

        if element then
            local old = index
            index = index + 1
            return old, element
        else
            return nil
        end
    end
end

---@param self Queue
function Queue:clear()
    for k, _ in pairs(self) do
        self[k] = nil
    end
    self._head, self._tail = 1, 1
end

return Queue