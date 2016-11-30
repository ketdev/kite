package kite;

import haxe.ds.Vector;
import haxe.ds.IntMap;
import kite.ds.ObjectPool;

@:allow(kite.Kite)
@:allow(kite.DataEntity)
class Flow{

    // // readonly properties
    // public var nodes(get,null):Iterator<kite.INode>;
    // public var data(get,null):Iterator<kite.DataEntity>;
    // public var components(get,null):Iterator<kite.IComponent>;

    // api methods
    public function push(nodes:Array<kite.INode>, ?pos:UInt){
        if(nodes == null) return;
        if(pos == null) pos = 0;
        
        // add nodes at correct position in flow
        _nodes = _nodes.slice(0,pos)
            .concat(nodes)
            .concat(_nodes.slice(pos,_nodes.length));
        
        // add uid mapping
        for(node in nodes){
			var type:Class<kite.INode> = cast Type.getClass(node);
            var uid = _getNodeUid(type);            
            _node2Uid.set(node,uid);
            
            // add all data indices to pending
            var p = _pendingMatches[uid];
            for(i in _dataPool)
                p.set(p.alloc(),i);
        }

    }
    public function pop(count:UInt, ?pos:UInt):Array<kite.INode>{
        if(pos == null) pos = _nodes.length;
        var removed = _nodes.splice(pos,count);

        for(node in removed){
            var uid = _node2Uid[node];
            // clear pending and matches
            _pendingMatches[uid].reset();
            _matchedData[uid].reset();

            // unmap uids
            _node2Uid.remove(node);
        }
        return removed;
    }
    public function execute(){
        // iterate on nodes, they (should be) inmutable during execution
        for(node in _nodes){
            // get node type data
            var nodeuid = _node2Uid.get(node);
            var isSource = _nodeSource.get(nodeuid);

            // invoke sources without any data & components
            if(isSource){
                // kite.Kite 
                // kite.DataEntity 
                // haxe.ds.Vector<kite.IComponent> 
                untyped node.__kite_invoke__(_kite,null,null);
            }else{
                var requirements = _nodeRequirements.get(nodeuid);
                var matched = _matchedData[nodeuid];
                var pending = _pendingMatches[nodeuid];

                // push all matches onto queue
                _matchQueue.reset();
                for(i in matched){
                    // check if still relevant
                    var dataIndex = matched.get(i);
                    if(_dataPool.get(dataIndex) == null)
                        continue;
                    _matchQueue.push(dataIndex);
                }
                // clear matched, and add later again if match
                matched.reset();

                // handle all (mutable) matches
                do{
                    // push pending matches
                    for(i in pending)
                        _matchQueue.push(pending.get(i));
                    pending.reset();

                    // pop from queue
                    var isMatch = true;
                    var dataIndex = _matchQueue.pop();
                    var data = _dataPool.get(dataIndex);

                    // check if data has been removed
                    if(data != null){
                        // check data components
                        var isMatch = true;
                        for(i in 0...requirements.length){
                            var componentUid = requirements[i];
                            var componentIndex = data._components[componentUid];
                            if(componentIndex == Flow.NullIndex){
                                isMatch = false;
                                break; // missmatch
                            }

                            // get component value
                            var component = _componentTable[componentUid].get(componentIndex);
                            
                            // fill invoke arguments buffer
                            _componentArgs[i] = component;
                        }

                        if(isMatch){
                            // add to matched for next invoke
                            matched.push(dataIndex);

                            // invoke node update
                            untyped node.__kite_invoke__(_kite,data,_componentArgs);
                        } 
                    }
                }while(_matchQueue.length > 0);
            }            
        }
    }

    public function toString():String{
        return _nodes.toString();
    }

    // Internal 

    @:allow(kite.Kite)
    private function new(kite:kite.Kite){
        // Map uids & requirements from metadata
        _mapMetadata();

        _kite = kite;

        // preallocate data pool
        _dataPool = new ObjectPool<DataEntity>( DataEntity.new.bind(this) );  
        
        // preallocate component pool
        _componentTable = new Vector<ObjectPool<kite.IComponent>>( _componentCount );
        for(uid in 0..._componentTable.length){
            if(!_componentUid2Type.exists(uid)){
                // this happends if dce erased a component at compile time            
                _componentTable[uid] = new ObjectPool<kite.IComponent>( function(index:Int) return null );
            } else {
                var type = _componentUid2Type.get(uid);
                _componentTable[uid] = new ObjectPool<kite.IComponent>( function(index:Int) 
                    return Type.createInstance(type,[]) 
                );
            }
        }

        // preallocate match pools
        _pendingMatches = new Vector<ObjectPool<Int>>( _nodeCount );
        _matchedData = new Vector<ObjectPool<Int>>( _nodeCount );
        for(uid in 0..._nodeCount){
            _pendingMatches[uid] = new ObjectPool<Int>( function(index:Int) return NullIndex );
            _matchedData[uid] = new ObjectPool<Int>( function(index:Int) return NullIndex );
        }
        _matchQueue = new ObjectPool<Int>( function(index:Int) return NullIndex );

        // preallocate component argument buffer
         // max length is one of each component
        _componentArgs = new Vector<IComponent>( _componentCount );
    }

    /**
        Kite - passed to nodes for data manipulation
        Data Pool - [mutable] index -> data
        Component Table - [mutable] uid -> index -> component 
        Nodes - [inmutable], with map to get fast uid

        Matched Data    - [mutable] node uid -> _ -> data index 
        Pending Matches - [mutable] node uid -> _ -> data index
        Match Queue     - _ -> data index: not yet invoked matches
        Component Args  - passed to node invokation, reused for all nodes
    **/ 

    private var _kite:kite.Kite;
    private var _dataPool:ObjectPool<kite.DataEntity>;
    private var _componentTable:Vector<ObjectPool<kite.IComponent>>;
    private var _nodes = new Array<kite.INode>();
    private var _node2Uid = new Map<kite.INode,Int>();

    private var _pendingMatches:Vector<ObjectPool<Int>>;
    private var _matchedData:Vector<ObjectPool<Int>>;
    private var _matchQueue:ObjectPool<Int>;
    private var _componentArgs:Vector<kite.IComponent>;

    // Metadata maps for fast access

    private static inline var NullIndex = -1; 
    private static var _mappedMetadata = false;
    private static var _componentCount:Int;
    private static var _componentUid2Type:IntMap<Class<kite.IComponent>>;    
    private static var _nodeCount:Int;
    private static var _nodeRequirements:IntMap<Array<Int>>; // component uids
    private static var _nodeSource:IntMap<Bool>; // if is data independent
    private static var _nodeUid2Type:IntMap<Class<kite.INode>>;
    private static function _mapMetadata(){
        if(_mappedMetadata) return; // map once only
        _mappedMetadata = true;

        _componentCount = 0;
        _componentUid2Type = new IntMap<Class<kite.IComponent>>();
        _nodeCount = 0;
        _nodeUid2Type = new IntMap<Class<kite.INode>>();
        _nodeRequirements = new IntMap<Array<Int>>();
        _nodeSource = new IntMap<Bool>();

        // Get metadata list
        var meta = haxe.rtti.Meta.getType(kite.Flow);

        if(meta.kite_components != null){
            var list:Array<String> = meta.kite_components[0];
            for (name in list){
				var type:Class<kite.IComponent> = cast Type.resolveClass(name);
                if(type == null) continue;
                var uid = _getComponentUid(type);
                _componentUid2Type.set(uid,type);
                var max:Int = uid + 1;
                _componentCount = _componentCount > max ? _componentCount : max;
                //#if debug trace('Component $uid: $name'); #end
            }
        }
        if(meta.kite_nodes != null){
            var list:Array<String> = meta.kite_nodes[0];
            for (name in list){
				var type:Class<kite.INode> = cast Type.resolveClass(name);
                if(type == null) continue;
                var uid = _getNodeUid(type);
                var req = _getNodeRequirements(type);
                // get requirement components
                var reqComponents:Array<String> = cast req.components;
                var components = new Array<Int>();
                for(cname in reqComponents){
				    var ctype:Class<kite.IComponent> = cast Type.resolveClass(cname);
                    if(ctype == null) continue;
                    var uid = _getComponentUid(ctype);
                    components.push(uid);
                }
                _nodeUid2Type.set(uid,type);
                _nodeRequirements.set(uid,components);
                _nodeSource.set(uid,req.dataIndex < 0 && reqComponents.length == 0);                
                var max:Int = uid + 1;
                _nodeCount = _nodeCount > max ? _nodeCount : max;
                //#if debug trace('Node $uid: $name, requires: $components source: ${_nodeSource.get(uid)}'); #end
            }
        }
    }
    private static function _getComponentUid(component:Class<kite.IComponent>):Int {
        return component != null ? haxe.rtti.Meta.getType(component).kite_uid[0] : NullIndex;
    }
    private static function _getNodeUid(node:Class<kite.INode>):Int {
        return node != null ? haxe.rtti.Meta.getType(node).kite_uid[0] : NullIndex;
    }
    private static function _getNodeRequirements(node:Class<kite.INode>):Dynamic {
        return node != null ? haxe.rtti.Meta.getType(node).kite_requirements[0] : NullIndex;
    }

}