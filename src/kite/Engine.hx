package kite;

import haxe.ds.Vector;
import kite.internal.ObjectPool;
import kite.internal.MatchedEntity;
import kite.internal.MatchedSystem;
import kite.internal.sugar.ComponentIndex;
import kite.internal.sugar.SystemIndex;
import kite.macro.ComponentMapper;

import Type;

class Engine implements kite.internal.Internal{

    public static inline var NullIndex = -1;

    // Index = Entity
    private var _entities:ObjectPool<MatchedEntity>;

    // All components: uid->index->component
    private var _components:Vector<ObjectPool<IComponent>>;
    
    // Index = SystemIndex
    private var _systems:ObjectPool<MatchedSystem>;

    public function new() {
        var componentCount = ComponentMapper.count();

        // MatchedEntities store their component indices, and matched systems links
        _entities = new ObjectPool<MatchedEntity>( MatchedEntity.new );

        // preallocate component pool
        _components = new Vector<ObjectPool<IComponent>>( componentCount );
        for(uid in 0..._components.length){
            var type = ComponentMapper.getClass(uid);
            if(type == null) // this happends if dce erased a component at compile time                
                _components[uid] = new ObjectPool<IComponent>( function(index:ComponentIndex) return null );
            else
                _components[uid] = new ObjectPool<IComponent>( function(index:ComponentIndex) return Type.createInstance(type,[]) );
        }

        // Although matched systems are pooled, they reference an user allocated system
        // hopefully they don't change much. Adding and removing systems each frame can be a killer :)
        // We use ObjectPool so that the index doesn't change after adding/removing items
        _systems = new ObjectPool<MatchedSystem>( MatchedSystem.new );
    }

    // Getting entities makes a copy 
    public var entities(get,null):Array<Entity>;
    private function get_entities():Array<Entity>
        return [for(e in _entities) e];

    // Getting components makes a copy 
    public var components(get,null):Array<IComponent>;
    private function get_components():Array<IComponent>
        return [for(pool in _components) for(i in pool) pool.get(i)];
        
    // Getting systems makes a copy 
    public var systems(get,null):Array<ISystem>;
    private function get_systems():Array<ISystem>
        return [for(i in _systems) _systems.get(i).system];
    
    public function newEntity(?components:Iterable<Class<IComponent>>):Entity {
        var e:Entity = _entities.alloc(); // entity equals the index itself
        addComponents(e,components);
        return e;
    }
    public function addComponents(entity:Entity, components:Iterable<Class<IComponent>>){
        var me = _entities.get(entity);
        if(me == null) return; // invalid entity

        // remove all previous links to this entity
        me.disconnect();

        for(c in components){
            var uid = ComponentMapper.getUid(c);   

            // skip if entity already has that component
            if(me.hasComponent(uid)) continue;

            // allocate component and bind to entity     
            me.setComponentIndex(uid,_components[uid].alloc());
        }
        // match entity to all existing systems
        for(s in _systems) _match(_systems.get(s),me);
    }
    public function removeComponents(entity:Entity, components:Iterable<Class<IComponent>>){
        var me = _entities.get(entity);
        if(me == null) return; // invalid entity

        // remove all previous links to this entity
        me.disconnect();
        
        // free components
        for(c in components){
            var uid = ComponentMapper.getUid(c);
            _components[uid].free(me.removeComponent(uid));
        }
        
        // match entity to all existing systems
        for(s in _systems) _match(_systems.get(s),me);
    }
    public function freeEntity(entity:Entity){
        var me = _entities.get(entity);
        if(me == null) return; // invalid entity

        // remove all links to this entity
        me.disconnect();
        
        // free all components
        for(uid in 0...me.components.length){
            _components[uid].free(me.removeComponent(uid));
        }

        // free entity
        _entities.free(entity);
    }

    public function select<T:IComponent>(entity:Entity, component:Class<T>):T {
        var me = _entities.get(entity);
        if(me == null) return null; // invalid entity
        
        var uid = ComponentMapper.getUid(cast component);
        var index = me.components[uid];
        var component = _components[uid].get(index);
        return cast component;
    }

    public function addSystems(systems:Iterable<ISystem>){
        for (system in systems){            
            // check if already added
            // adding and removing systems is relatively slow
            var found = false;
            for(index in _systems)
                if(_systems.get(index).system == system){
                    found = true;
                    break;
                }
            if(found) continue;
            
            // get new system index
            var m:SystemIndex = _systems.alloc();
            var ms = _systems.get(m);
            // initialize to user provided system
            ms.setSystem(system);
            // match new system to all existing entities
            for(e in _entities) _match(ms,_entities.get(e));
        }
    }
    public function removeSystems(systems:Iterable<ISystem>){
        for(system in systems){
            // find system index in _systems
            // adding and removing systems is relatively slow
            for(index in _systems){
                var ms = _systems.get(index);
                if(ms.system == system){
                    // remove all links to this system
                    ms.disconnect();

                    // free from pool
                    _systems.free(index);

                    break; // !important (we modified the pool iteration)
                }
            }
        }
    }
    public function update(){
        for(s in _systems) _systems.get(s).invoke(_components);
    }

    private function _match(system:MatchedSystem, entity:MatchedEntity){
        // match new links
        var systemLink = system.match(entity);
        if(systemLink != null){
            var entityLink = entity.newLink();
            // link system with entity
            systemLink.connect(system,entity,entityLink);
            entityLink.connect(system,entity,systemLink);
        }
    }

}