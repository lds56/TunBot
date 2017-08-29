local utf8 = require 'lua-utf8'
local cjson = require 'cjson'
local http = require 'socket.http'
local multipart = require 'multipart'

local open = io.open

local function read_file(path)
   local file = open(path, "rb") -- r read mode and b binary mode
   if not file then return nil end
   local content = file:read "*a" -- *a or *all reads the whole file
   file:close()
   return content
end

local function randommusic(playlist_id)
   local playlist_info = http.request('http://127.0.0.1:3000/playlist/detail?id=' .. playlist_id)
   local track_ids = cjson.decode(playlist_info).playlist.trackIds

   local track_rnd_id = track_ids[math.random(#track_ids)].id
   local track_info = http.request('http://127.0.0.1:3000/music/url?id=' .. track_rnd_id)

   return cjson.decode(track_info).data[1].url, track_rnd_id
end

local mem = cjson.decode(read_file("memory.json"))
local state = "NO_STATE"

local countdowntable = {}

local randomreply = function(replytable)
   if type(replytable) == 'table' then
	  return replytable[math.random(#replytable)]
   else
	  return "ERROR 404 >_<"
   end
end

math.randomseed( os.time() )

local api = require('telegram-bot-lua.core').configure('428105087:AAFToIwKvqxEEnrGR8rGjev9y2fxFLBbg1o')

function api.on_message(message)
   if message.text then
	  print('message: ' .. message.text)
   end
   
   if message.text then
	 if message.text:match('ping')
	 then
		state = 'NO_STATE'
		 api.send_message(
			message.chat.id,
			utf8.char(0xF0,0x9F,0x93,0x8C)
		 )
     elseif message.text:match('done') then
		state = 'NO_STATE'
		api.send_message(
		   message.chat.id,
		   'Done.'
		)
	 elseif message.text:match('/tips') then
		state = "NO_STATE"
		api.send_message(
		   message.chat.id,
		   randomreply(mem.tips)
		)
	 elseif message.text:match('/treehole') then
		state = "TREE_HOLE"
		api.send_message(
		   message.chat.id,
		   randomreply(mem.treehole.firstreply)
		)
	 elseif message.text:match('/imfeeling') then
		state = 'NO_STATE'
		api.send_message(
		   message.chat.id,
		   'Tell me what you are feeling now :P',
		   nil,
		   true,
		   false,
		   nil,
		   api.inline_keyboard():row(
			  api.row():callback_data_button(
				 'Lucky',
				 'feeling:lucky'
			  ):callback_data_button(
				 'Happy',
				 'feeling:happy'
			  )
	       ):row(
			  api.row():callback_data_button(
				 'Blue',
				 'feeling:blue'
			  ):callback_data_button(
				 'Green',
				 'feeling:green'
			  )
     	   )
		)
	 elseif message.text:match('/countdown') then
		state = "COUNT_DOWN_DESC"
		api.send_message(
		   message.chat.id,
		   mem.countdown.adddescreply
		)
	 elseif message.text:match('/countlist') then
		state = 'NO_STATE'
		local countlist = {}
		local countshow = function (cd)
		   local datenum = tonumber(cd.date)
		   local date = os.time{year=math.floor(datenum / 10000), month=math.floor(datenum/100) % 100, day=datenum % 100}
		   local datedelta = math.ceil(os.difftime(date, os.time()) / (24 * 60 * 60))
		   if datedelta >= 0 then
			  return 'Event: ' .. cd.desc .. ', Date: ' .. cd.date .. ', Countdown: ' .. datedelta .. ' days left'
		   else
			  return 'Event: ' .. cd.desc .. ', Date: ' .. cd.date .. ', Countdown: ' .. -datedelta .. ' days passed'
		   end
		end
		for i,v in ipairs(countdowntable) do
		   table.insert(countlist, countshow(v))
		end
		api.send_message(
		   message.chat.id,
		   table.concat(countlist, '\n')
		)
	 elseif message.text:match('/dailyneko') then
	    state = 'NO_STATE'
	    local cat_html = http.request('http://thecatapi.com/api/images/get?format=html')
	    local cat_url = string.match(cat_html, 'src="(.+)"')
	    
	    api.send_photo(
	       message.chat.id,
	       cat_url,
	       'Neko Chan~'
	    )
	 else
		if state == "TREE_HOLE" then
		   api.send_message(
			  message.chat.id,
			  randomreply(mem.treehole.laterreply) .. mem.treehole.donereply
		   )
		elseif state == 'COUNT_DOWN_DESC' then
		   table.insert(countdowntable, {desc = message.text, date = {}})
		   state = 'COUNT_DOWN_DATE'
		   api.send_message(
			  message.chat.id,
			  mem.countdown.adddatereply
		   )
		elseif state == 'COUNT_DOWN_DATE' then
		   state = 'NO_STATE'
		   countdowntable[#countdowntable].date = message.text
		   print('desc :' .. countdowntable[#countdowntable].desc)
		   api.send_message(
			  message.chat.id,
			  mem.countdown.adddonereply
		   )
		end
	 end
   end
end

function api.on_callback_query(callback_query)
   local message = callback_query.message
   print(callback_query.data)
   if callback_query.data:match('^feeling%:') then
      local feeling = callback_query.data:match('^feeling%:(.-)$')
      local playlist = mem.iamfeeling.options[feeling]
      
      assert(playlist, "Playlist is null!")
      
      local music_url, music_id = randommusic(playlist)
      -- local music = http.request(music_url)
      -- local multi_music = multipart(music, {Content-Type="audio/mp3", Content-Disposition='form-data; name="audio"; filename="Sound-1.mp3"'})
      
      -- print("music: " .. music_url)
	  -- if feeling == 'Lucky' then
	  -- end
	 return api.edit_message_text(
		 message.chat.id,
		 message.message_id,
		 -- music_url
		 "I've prepare a song for you!\nhttps://music.163.com/#/song?id=" .. music_id
	  )

	 -- return api.send_audio(
	 --    message.chat.id,
	 --    multi_music
	 --    "Lalala",
	 --    120,
	 --    "lds",
	 --    "Lalala"
	 --)
   end
end

print("Running...")
api.run()
