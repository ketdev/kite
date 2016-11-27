package kite.internal;

import haxe.ds.Vector;
import kite.Entity;
import kite.Engine;
import kite.internal.MatchedLink;
import kite.internal.sugar.ComponentUID;
import kite.internal.sugar.ComponentIndex;
import kite.macro.ComponentMapper;

class MatchedEntity implements kite.internal.Internal {
    // on creation
    private var _entity:Entity;
    // on setting components
    private var _components:Vector<ComponentIndex>; // index = component uid 
    // on matching
    private var _matched:ObjectPool<MatchedLink>;

    @:allow(kite.internal.Internal)
    private function new(entity:Entity){
        // set index = entity
        _entity = entity;
        _matched = new ObjectPool<MatchedLink>( MatchedLink.newEntityLink );

        // preallocate component map, with compile time known component count
        var componentCount = ComponentMapper.count();
        _components = new Vector<ComponentIndex>( componentCount );

        // initialize as cleared
        for(i in 0...componentCount) 
            _components[i] = Engine.NullIndex; 
    }


    public function setComponentIndex(uid:ComponentUID, index:ComponentIndex)
        _components.set(uid,index);
    public function removeComponent(uid:ComponentUID):ComponentIndex {
        var index = _components[uid];
        setComponentIndex(uid,Engine.NullIndex);
        return index;
    }

    public var entity(get,null):Entity;
    private function get_entity():Entity 
        return _entity;
    public var components(get,null):Vector<ComponentIndex>;
    private function get_components():Vector<ComponentIndex>
        return _components;    
    public inline function hasComponent(uid:ComponentUID):Bool
        return _components.get(uid) != Engine.NullIndex;
        
    public function newLink()
        return _matched.get(_matched.alloc());    
    public function disconnect()
        while(_matched.length > 0) // cannot loop while removing so we do this instead
            _matched.get(_matched.iterator().next()).disconnect(); 
    public function freeLink(index:Int)
        _matched.free(index);
    
}
