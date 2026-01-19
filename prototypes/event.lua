local events = {
    'on_tile_revealed',
}

for _, event_name in pairs(events) do
    data:extend({
        {
            type = 'custom-event',
            name = event_name
        }
    })
end