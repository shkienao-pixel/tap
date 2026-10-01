local configRoot = arg and arg[1] or '.'
local rules = dofile(configRoot .. '/tap-shortcuts.lua')
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local off, on = rules.defaults(), rules.defaults()
for _, item in ipairs(rules.definitions) do check(off[item.id] == false, 'default off: '..item.id);on[item.id] = true end
check(not rules.any(off), 'no default listener')
local context = {bundle = 'com.google.Chrome', editable = true}
local function resolves(key, flags, expectedKey, expectedFlag, options, ctx)
    local result = rules.resolve(key, flags, ctx or context, options or on)
    check(result and result.key == expectedKey and (not expectedFlag or result.flags[expectedFlag]), 'mapping '..key)
end
resolves('left',{cmd=true},'left','alt')
resolves('right',{cmd=true,shift=true},'right','shift')
resolves('delete',{cmd=true},'delete','alt')
resolves('forwarddelete',{cmd=true},'forwarddelete','alt')
resolves('home',{},'left','cmd')
resolves('end',{shift=true},'right','shift')
resolves('home',{cmd=true,shift=true},'up','shift')
resolves('end',{cmd=true},'down','cmd')
resolves('y',{cmd=true},'z','shift')
resolves('tab',{cmd=true},'tab','ctrl')
resolves('tab',{cmd=true,shift=true},'tab','shift')
resolves('f4',{alt=true,fn=true},'w','cmd')
resolves('f2',{},'return',nil,on,{bundle='com.apple.finder',editable=false})
resolves('s',{ctrl=true,shift=true},'4','ctrl')
resolves('f13',{},'3','ctrl')
for _, key in ipairs({'left','right','delete','forwarddelete','home','end','y','tab','f2','f4','f13','s'}) do
    for _, flags in ipairs({{}, {cmd=true}, {alt=true}, {ctrl=true,shift=true}}) do
        check(rules.resolve(key,flags,context,off)==nil, 'disabled pass-through')
    end
end
check(rules.resolve('left',{cmd=true},{bundle='com.apple.Terminal',editable=true},on)==nil,'terminal pass-through')
check(rules.resolve('home',{},{bundle='com.google.Chrome',editable=false},on)==nil,'non-text pass-through')
check(rules.resolve('tab',{cmd=true},{bundle='com.apple.finder'},on)==nil,'browser scope')
check(rules.resolve('f2',{},{bundle='com.apple.finder',editable=true},on)==nil,'rename input pass-through')
check(rules.resolve('left',{cmd=true,alt=true},context,on)==nil,'extra modifiers pass-through')
check(rules.resolve('tab',{cmd=true},{bundle='com.google.Chrome',secureInput=true},on)==nil,'secure input')
check(rules.resolve('tab',{cmd=true},{bundle='com.google.Chrome',nativeTabActive=true},on)==nil,'native switcher guard')
check(rules.defaults({wordDelete=true,unknown=true}).unknown==nil,'unknown options ignored')

-- Mock only the engine boundary. These options and events never touch live settings or macOS.
local store, callback, listener, globalEnabled, secure, nativeActive = {}, nil, false, true, false, false
local bundle, role = 'com.google.Chrome', 'AXTextField'
local codes = {left=123,right=124,delete=51,forwarddelete=117,home=115,['end']=119,up=126,down=125,tab=48,y=16,z=6,f4=118,f2=120,f13=105,s=1,['4']=21,['3']=20,w=13,['return']=36}
local reverse={}
for key,code in pairs(codes) do reverse[code]=key end
for code,key in pairs(reverse) do codes[code]=key end
local front={bundleID=function()return bundle end}
local element={setTimeout=function(self)return self end,attributeValue=function(self,name)if name=='AXRole' then return role end end}
local root={setTimeout=function(self)return self end,attributeValue=function(self,name)if name=='AXFocusedUIElement' then return element end end}
hs={
 settings={get=function(key)return store[key] end,set=function(key,value)store[key]=value end},
 keycodes={map=codes},
 application={frontmostApplication=function()return front end},
 axuielement={applicationElement=function()return root end},
 eventtap={isSecureInputEnabled=function()return secure end,event={types={keyDown=10,keyUp=11},properties={eventSourceUserData=42,keyboardEventAutorepeat=43}}},
}
function hs.eventtap.new(types,fn)
 callback=fn
 return {start=function(self)listener=true;return self end,stop=function(self)listener=false;return self end,isEnabled=function()return listener end}
end
local app={refreshUI=function()end}
local runtime={generatedEvent=77,isEnabled=function()return globalEnabled end,nativeTabActive=function()return nativeActive end,resetShift=function()end}
dofile(configRoot .. '/tap-compat.lua')(app,rules,runtime)
app.applyCompatSettings();check(not listener,'live default listener stopped')
local function event(key,flags,kind,tag)
 local e={code=codes[key],flags=flags or {},kind=kind or 10,tag=tag or 0}
 function e:getKeyCode()return self.code end
 function e:getFlags()return self.flags end
 function e:getType()return self.kind end
 function e:getProperty(property)if property==43 then return self.isRepeat and 1 or 0 end;return self.tag end
 function e:setProperty(property,value)if property==43 then self.isRepeat=value~=0 else self.tag=value end;return self end
 function e:setKeyCode(code)self.code=code;return self end
 function e:setFlags(flags)self.flags=flags;return self end
 return e
end
function hs.eventtap.event.newKeyEvent(modifiers,key,down) return event(key,{},down and 10 or 11) end
local function mapped(e) local stop,outputs=callback(e);return stop,outputs and outputs[1] end
local untouched=event('tab',{cmd=true});callback(untouched);check(untouched.code==codes.tab and untouched.flags.cmd and not untouched.flags.ctrl,'default untouched')
app.setCompatOption('browserTabs',true);check(listener and store['tap.compatOptions'].browserTabs,'mock preference saved')
local generated=event('tab',{cmd=true},10,77);callback(generated);check(generated.flags.cmd,'generated Cmd+Tab untouched')
local down=event('tab',{cmd=true});local stop,output=mapped(down);check(stop and output.flags.ctrl and not output.flags.cmd,'browser down remapped');check(down.flags.cmd,'original event unchanged')
app.setCompatOption('browserTabs',false);check(listener,'held key still gets release')
bundle='com.apple.finder'
local up=event('tab',{},11);stop,output=mapped(up);check(stop and output.flags.ctrl and not listener,'key release survives app change/disable')
app.setCompatOption('closeWindow',true)
local close=event('f4',{alt=true});stop,output=mapped(close);check(stop and output.code==codes.w and output.flags.cmd,'close mapped')
local repeated=event('f4',{alt=true});repeated.isRepeat=true;check(callback(repeated)==true and repeated.code==codes.f4,'repeat close suppressed')
globalEnabled=false;app.applyCompatSettings();check(listener,'pause drains held key')
callback(event('f4',{},11));check(not listener,'paused engine stopped after release')
globalEnabled=true;app.setCompatOption('closeWindow',false)
app.setCompatOption('wordNavigation',true);bundle='com.google.Chrome'
local text=event('left',{cmd=true,shift=true});stop,output=mapped(text);check(stop and output.flags.alt and output.flags.shift,'AX text context')
callback(event('left',{},11));role='AXWebArea'
local web=event('left',{cmd=true});callback(web);check(web.flags.cmd and not web.flags.alt,'web non-editable untouched')
role='AXTextField';callback(event('left',{cmd=true}));app.setCompatOption('wordNavigation',false);local fresh=event('left',{cmd=true});stop,output=mapped(fresh);check(stop==false and not output and fresh.flags.cmd,'lost release respects disabled option');app.applyCompatSettings()
for _,item in ipairs(rules.definitions) do app.setCompatOption(item.id,false) end
check(not listener and not rules.any(app.compatStatus()),'mock options returned off')
print('PASS: '..checks..' compatibility checks; live options never enabled')
