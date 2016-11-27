package kite.macro;

import kite.internal.sugar.ComponentUID;

class ComponentMapper{

    #if !macro
    @:allow(kite.internal.Internal)
    private static function count():Int {
        if(!_initialized) 
            initialize(); 
        return _count;
    }
    
    @:allow(kite.internal.Internal)
    private static function getUid(component:Class<IComponent>):ComponentUID {
        if(component != null){
            var meta = haxe.rtti.Meta.getType(component);
            if(meta != null){
                // metadata is added as array, empty if not found
                for(uid in haxe.rtti.Meta.getType(component).uid)
                    return uid;     
            }
        }
        return kite.Engine.NullIndex;
    }
    
    @:allow(kite.internal.Internal)
    private static function getClass(uid:ComponentUID):Class<IComponent> {
        if(!_initialized) 
            initialize(); 
        if(!_uid2Type.exists(uid))
            return null;
        return _uid2Type.get(uid);
    }

    private static var _initialized = false;
    private static var _count = 0;
    private static var _uid2Type = new Map<ComponentUID,Class<IComponent>>();
    private static function initialize(){
        // get meta tag at runtime only first time
        _initialized = true;
        var meta = haxe.rtti.Meta.getType(ComponentMapper);
        if(meta.list != null){
            var list:Array<String> = meta.list[0];
            for (name in list){
				var type:Class<IComponent> = cast Type.resolveClass(name);
                if(type == null) continue;
                var uid = getUid(type);
                _uid2Type.set(uid,type);
                var max:Int = uid + 1;
                _count = if(_count > max) _count else max;
                //#if debug trace('Component $uid: $name'); #end
            }
        }      
    }
    #end
}
