package kite.internal;

import kite.internal.MatchedEntity;
import kite.internal.MatchedSystem;

// Links are a two sided connection between systems and entities
class MatchedLink implements kite.internal.Internal {
    private var _system:MatchedSystem;
    private var _entity:MatchedEntity;

    private var _index:Int;
    private var _systemSide:Bool;
    private var _dual:MatchedLink; // if connected

    private function new(){}

    @:allow(kite.internal.Internal)
    private static function newSystemLink(index:Int):MatchedLink{
        var link = new MatchedLink();
        link._index = index;
        link._systemSide = true;
        return link;
    }
    @:allow(kite.internal.Internal)
    private static function newEntityLink(index:Int):MatchedLink{
        var link = new MatchedLink();
        link._index = index;
        link._systemSide = false;
        return link;
    }
    
    public function connect(system:MatchedSystem, entity:MatchedEntity, dual:MatchedLink){
        _system = system;
        _entity = entity;
        _dual = dual;
    }
    public function disconnect(){
        if(_system == null || _entity == null) return; // already disconnected
        if(_dual != null){
            _dual._dual = null; // no infinite disconnecting
            _dual.disconnect(); // disconnect other side
        }

        if(_systemSide) _system.freeLink(_index);
        else            _entity.freeLink(_index);

        // reset state for pool reuse
        _system = null;
        _entity = null;
        _dual = null;
    }

    public var entity(get,null):MatchedEntity;
    private function get_entity():MatchedEntity return _entity;
    
}
