local utf8 = require 'lua-utf8'
local cjson = require 'cjson'
local http = require 'socket.http'
local multipart = require 'multipart'
local feedparser = require 'feedparser'

---- util funcs
local function read_file(path)
   local file = io.open(path, "rb") -- r read mode and b binary mode
   if not file or file == '' then return nil end
   local content = file:read "*a" -- *a or *all reads the whole file
   file:close()
   return content
end

local function write_file(path, data)
   local file = io.open(path, "w")
   if not file then return nil end
   file:write(data)
   file:close()
end

local function randommusic(playlist_id)
   local playlist_info = http.request('http://127.0.0.1:3000/playlist/detail?id=' .. playlist_id)
   local track_ids = cjson.decode(playlist_info).playlist.trackIds

   local track_rnd_id = track_ids[math.random(#track_ids)].id
   local track_info = http.request('http://127.0.0.1:3000/music/url?id=' .. track_rnd_id)

   return cjson.decode(track_info).data[1].url, track_rnd_id
end

local function randomreply(replytable)
   if type(replytable) == 'table' then
      return replytable[math.random(#replytable)]
   else
      return "ERROR 404 >_<"
   end
end

local countdowntable = cjson.decode(read_file("countdown.json") or '{}')
local function getcdtable(id)
   local id_str = tostring(id)
   countdowntable[id_str] = countdowntable[id_str] or {}
   assert(type(countdowntable) == 'table', 'Countdown table should be a table')
   return countdowntable[id_str]
end

---- global variables
local mem_content = read_file("memory.json")
assert(mem_content, "No memory.json found")
local mem = cjson.decode(mem_content)
local state = "NO_STATE"
local miao_url = 'http://staymiao.lofter.com/'
local now_datenum = 0

-- local countdownfile ="count
-- assert(countdownfile, "Countdown file not exist")

math.randomseed( os.time() )

local api = require('telegram-bot-lua.core').configure(mem.token)

---- api part
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
		    'pong'
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
		   assert(datenum, 'Invalid date')
		   
		   local date = os.time{year=math.floor(datenum / 10000), month=math.floor(datenum/100) % 100, day=datenum % 100, hour=0}
		   local datedelta = os.difftime(date, os.time()) / (24 * 60 * 60)
		   if datedelta >= 0 then
		      return utf8.escape('%x1F4CB') .. ' ' .. cd.desc .. '  ' ..
			 utf8.escape('%x1F4C5') .. ' ' .. cd.date .. '  ' ..
			 utf8.escape('%x23F3') .. ' ' .. math.ceil(datedelta) .. ' days left'
		   else
		      return utf8.escape('%x1F4CB') .. ' ' .. cd.desc .. '  ' ..
			 utf8.escape('%x1F4C5') .. ' ' .. cd.date .. '  ' ..
			 utf8.escape('%x231B') .. ' ' .. math.ceil(-datedelta) .. ' days passed'
		   end
		end

		for i,v in ipairs(getcdtable(message.chat.id)) do
		      table.insert(countlist, countshow(v))
		end

		api.send_message(
		   message.chat.id,
		   #countlist > 0 and table.concat(countlist, '\n') or "IT'S VOID :("
		)
	 elseif message.text:match('/dailyneko') then
	    state = 'NO_STATE'

	    api.send_message(
	       message.chat.id,
	       'Please choose the neko channel :3',
	       nil,
	       true,
	       false,
	       nil,
	       api.inline_keyboard():row(
		  api.row():callback_data_button(
		     'I\'m Feeling Lucky',
		     'neko:lucky'
		  ):callback_data_button(
		     'Staymiao',
		     'neko:miao'
		  )
		)
	    )
	    
	 else
		if state == "TREE_HOLE" then
		   api.send_message(
			  message.chat.id,
			  randomreply(mem.treehole.laterreply) .. mem.treehole.donereply
		   )
		elseif state == 'COUNT_DOWN_DESC' then
		   state = 'COUNT_DOWN_DATE'
		   
		   table.insert(getcdtable(message.chat.id), {desc = message.text, date = {}})

		   api.send_message(
			  message.chat.id,
			  mem.countdown.adddatereply
		   )
		   
		elseif state == 'COUNT_DOWN_DATE' then
		   if not tonumber(message.text) then
		      return api.send_message(
			 message.chat.id,
			 'Please input date in correct format.'
		      )
		   end
		      
		   state = 'NO_STATE'
		   
		   local thetable = getcdtable(message.chat.id)
		   thetable[#thetable].date = message.text

		   if not pcall(function()
			 write_file('countdown.json', cjson.encode(countdowntable))
		   end) then
		      assert(false, "Countdown table cannot be jsonified")
		   end

--		   countdownfile:flush()
		   
		   print('desc :' .. thetable[#thetable].desc)
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
   elseif callback_query.data:match('^neko%:') then
      local neko = callback_query.data:match('^neko%:(.-)$')

      local generatemarkup = function(msg, callback_type)
	 return api.inline_keyboard():row(
	    api.row():callback_data_button(
	       msg,
	       'neko:' .. callback_type
	    ):callback_data_button(
	       'Nope',
	       'neko:done'
	    )
	 )
      end
      
      if neko == 'lucky' then

	 print('lucky lucky: ' .. message.message_id)
	 
	 local cat_html = http.request('http://thecatapi.com/api/images/get?format=html')
	 local cat_url = string.match(cat_html, 'src="(.+)"')

	 local res = api.send_photo(
	    message.chat.id,
	    cat_url,
	    'Neko Chan~',
	    false,
	    nil,
	    generatemarkup('Just one more neko', 'lucky')
	 )

	 return api.edit_message_reply_markup(
	    message.chat.id,
	    message.message_id,
	    nil,
	    not res and generatemarkup('Oops, try another one neko', 'lucky') or nil
	 )
	 
      elseif neko:find('^miao') then

	 print('miao miao: ' .. message.message_id)

	 local index = string.match(neko, 'miao(%d+)') or 1
	 local rss = feedparser.parse(read_file('staymiao.xml'), miao_url)
	 index = math.min(#rss.entries, index)

	 print('miao index: ' .. index)
	 
	 local link = rss.entries[index].link
	 local title = rss.entries[index].title
	 title = string.sub(title, 1, (string.find(title, '\n') or string.len(title)+1) - 1)
	 local img = string.match(rss.entries[index].summary, 'img src="(.-)"')

	 local res = api.send_photo(
	    message.chat.id,
	    img,
	    title .. '\n' .. link,
	    false,
	    nil,
	    generatemarkup('Just one more neko', 'miao' .. (index+1))
	 )
	 
	 return api.edit_message_reply_markup(
	    message.chat.id,
	    message.message_id,
	    nil,
	    not res and generatemarkup('Oops, try another one neko', 'miao'..(index+1)) or nil
	 )

      elseif neko == 'done' then

	 return api.edit_message_reply_markup(
	    message.chat.id,
	    message.message_id,
	    nil,
	    nil
	 )
	 
      end
   end
end

function api.on_run(run)
   
   if os.date('*t').min == 0 then
      local now_time = os.date('*t')
      local tmp_datenum = now_time.year * 10000 + now_time.month * 100 + now_time.day

      if now_datenum < tmp_datenum then

	 now_datenum = tmp_datenum
      
	 for user, cd in pairs(countdowntable) do
	    for idx, info in ipairs(countdowntable[user]) do
	       if tonumber(info.date) == now_datenum then
		  api.send_message(
		     user,
		     "It's time now => " .. info.desc
		  )
	       end
	    end
	 end
      end
   end
end

print("Running...")
api.run()

-- countdownfile:close()
