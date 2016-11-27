package kite.internal;

import haxe.ds.Vector;
import kite.macro.ComponentMapper;
import kite.internal.MatchedLink;
import kite.internal.MatchedEntity;
import kite.internal.sugar.SystemIndex;
import kite.internal.sugar.ComponentUID;

class MatchedSystem implements kite.internal.Internal {
    // on creation
    private var _index:SystemIndex;
    // on initialization
    private var _system:ISystem;
    private var _requires:Vector<ComponentUID>;
    // on matching
    private var _matched:ObjectPool<MatchedLink>;    
    // on invoke, reuse same vector with arguments to not allocate a new one on each invoke
    private var _args:Vector<IComponent>;
    
    public var system(get,null):ISystem;
    private function get_system():ISystem
        return _system;

    @:allow(kite.internal.Internal)
    private function new(index:SystemIndex){
        _index = index;
    }

    @:allow(kite.internal.Internal)
    private function setSystem(system:ISystem){
        _system = system;
        _matched = new ObjectPool<MatchedLink>( MatchedLink.newSystemLink );

        // build requirement mask
        var r = _system.__requires();
        _requires = new Vector<ComponentUID>(r.length);
        for(i in 0...r.length){
            var ctype = r[i];
            var uid = ComponentMapper.getUid(ctype);
            _requires[i] = uid;   
        }

        // build arguments vector, we know size here
        _args = new Vector<IComponent>(r.length);
    }

    // Stores the entity if the entity matches the system requirements
    public function match(entity:MatchedEntity):MatchedLink {
        // check requirements
        for(uid in _requires)
            if(!entity.hasComponent(uid))
                return null;            
        
        // entity has all required components
        return _matched.get(_matched.alloc());
    }
    public function disconnect()
        while(_matched.length > 0) // cannot loop while removing so we do this instead
            _matched.get(_matched.iterator().next()).disconnect(); 
    public function freeLink(index:Int)
        _matched.free(index);

    public function invoke(componentPool:Vector<ObjectPool<IComponent>>){
        for(l in _matched){
            var link = _matched.get(l);
            var componentIndices = link.entity.components;

            // fill invoke arguments
            for(i in 0..._requires.length){
                var uid = _requires[i];
                var index = componentIndices[uid];
                var component = componentPool.get(uid).get(index);
                _args[i] = component;
            }

            // invoke system update with correct arguments
            _system.__invoke(_args);
        }
    }

}