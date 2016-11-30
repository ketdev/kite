package kite;

import haxe.ds.Vector;

@:allow(kite.Kite)
@:allow(kite.Flow)
class DataEntity{
    
    /**
        Add specific components
    **/
    public function add(components:Iterable<Class<kite.IComponent>>){
        if(!_active) return; // destroyed
        for(c in components){
            if(has(c)) continue;
            var uid = Flow._getComponentUid(c);
            var componentIndex = _flow._componentTable[uid].alloc();
            _components[uid] = componentIndex;
        }

        // notify nodes that data has changed
        _notifyChanged();
    }
    
    /**
        Remove specific components
    **/
    public function remove(components:Iterable<Class<IComponent>>){
        if(!_active) return; // destroyed
        for(c in components){
            var uid = Flow._getComponentUid(c);
            var index = _components[uid];
            if(index == Flow.NullIndex) continue;
            _flow._componentTable[uid].free(index);
            _components[uid] = Flow.NullIndex;
        }
        
        // notify nodes that data has changed
        _notifyChanged();
    }

    /**
        Removes all components
    **/
    public function clear(){
        if(!_active) return; // destroyed
        for(uid in 0..._components.length){
            var index = _components[uid];
            if(index == Flow.NullIndex) continue;
            _flow._componentTable[uid].free(index);
            _components[uid] = Flow.NullIndex;
        }
        
        // notify nodes that data has changed
        _notifyChanged();
    }

    /**
        Checks if the data entity has the specified component type.
    **/
    public function has<T:kite.IComponent>(t:Class<T>):Bool{
        if(!_active) return false; // destroyed
        var uid = Flow._getComponentUid(cast t);
        return _components[uid] != Flow.NullIndex;
    }

    /**
        Returns the component value, or null if doesn't have one.
    **/
    public function select<T:kite.IComponent>(t:Class<T>):T {
        if(!_active) return null; // destroyed
        var uid = Flow._getComponentUid(cast t);
        var index = _components[uid];
        if(index == Flow.NullIndex) return null;
        var component = _flow._componentTable[uid].get(index);        
        return cast component;
    }

    /**
        Deallocates the data entity, returning it to the data pool.
        Using this object after destroying will cause unexpected behavior.
    **/
    public function destroy(){
        if(!_active) return; // already destroyed
        // remove all components
        clear();    
        // keep flow and index as-is, for next alloc
        _active = false;
        // return to pool
        _flow._dataPool.free(_index);
    }


    public function toString():String{
        if(!_active) return null; // destroyed
        var s = '[';
        var i = 0;
        for(uid in 0..._components.length){
            var index = _components[uid];
            if(index != Flow.NullIndex){
                s += '${_flow._componentTable[uid].get(index)}';
                if(i>0) s+=',';
                i++;
            }
        }
        s += ']';
        return s;
    }

    /**
        Active - in use or in pool
        Flow - associated flow
        Index - Data index in flow data pool
        Components - [mutable] uid -> index in flow component table, or nullindex
    **/ 

    private var _active:Bool;
    private var _flow:kite.Flow;
    private var _index:Int;
    private var _components:Vector<Int>;

    private function new(flow:kite.Flow, index:Int){
        _active = false;
        _flow = flow;
        _index = index;
        
        // preallocate component map, with compile time known component count
        _components = new Vector<Int>( kite.Flow._componentCount );
        for(uid in 0..._components.length) _components[uid] = Flow.NullIndex;        
    }

    private function _notifyChanged(){
        // set pending match as data changed on existing nodes
        // if node appears twice, add twice as pending, no big deal
        for(nodeuid in _flow._node2Uid){
            var p = _flow._pendingMatches[nodeuid];
            p.set(p.alloc(),_index);
        }
    }

} 