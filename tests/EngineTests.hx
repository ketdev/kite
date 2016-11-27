package tests;

import haxe.unit.TestCase;
import kite.Engine;
import kite.Entity;
import kite.IComponent;
import kite.ISystem;

class ComponentTest1 implements IComponent{
    public var x:Int = 0;
    public var y:Int = 1;
    public var z:Int = 2;
}
class ComponentTest2 implements IComponent{
    public var a:Int = 3;
    public var b:Int = 4;
}
class ComponentTest3 implements IComponent{
    public var __:Int = 5;
    public var ___:Int = 6;
}
class SystemTest1 implements ISystem{
    public static var count = 0;
    public function new(){}
    public function update(engine:Engine,entity:Entity,t0:ComponentTest1,t1:ComponentTest2){
        count++;
    }
}

class EngineTests extends TestCase{

    public function testEntities(){

        var engine = new Engine();

        // test empty entity
        var make = 7;
        var entities = new Array<Entity>();
        for(i in 0...make)
            entities.push(engine.newEntity([]));
        assertTrue(entities[0] != Engine.NullIndex);
        assertEquals(entities.length,engine.entities.length);

        // test removal
        var keep = 3;
        for(e in 0...entities.length-keep)
            engine.freeEntity(entities[e]);
        assertEquals(keep,engine.entities.length);
    }

    public function testComponents(){
        
        var engine = new Engine();

        // add some components at creation
        var make = 7;
        var entities = new Array<Entity>();
        for(i in 0...make)
            entities.push(engine.newEntity([ComponentTest1]));
        assertEquals(entities.length,engine.components.length);
        for(e in entities)
            assertTrue(engine.select(e,ComponentTest1) != null);

        // add some components after creation
        for(e in entities)
            engine.addComponents(e,[ComponentTest2, ComponentTest3]);
        assertEquals(entities.length * 3,engine.components.length);
        for(e in entities){
            assertTrue(engine.select(e,ComponentTest1) != null);
            assertTrue(engine.select(e,ComponentTest2) != null);
            assertTrue(engine.select(e,ComponentTest3) != null);
        }

        // remove some component
        for(e in entities)
            engine.removeComponents(e,[ComponentTest2]);
        assertEquals(entities.length * 2,engine.components.length);
        for(e in entities){
            assertTrue(engine.select(e,ComponentTest1) != null);
            assertTrue(engine.select(e,ComponentTest2) == null);
            assertTrue(engine.select(e,ComponentTest3) != null);
        }

        // free entities
        for(e in entities)
            engine.freeEntity(e);
        assertEquals(0,engine.components.length);
        for(e in entities){
            assertTrue(engine.select(e,ComponentTest1) == null);
            assertTrue(engine.select(e,ComponentTest2) == null);
            assertTrue(engine.select(e,ComponentTest3) == null);
        }
    }

    public function testSystems(){

        var engine = new Engine();

        // add no systems
        engine.addSystems([]);
        assertEquals(0,engine.systems.length);

        // add systems
        var make = 7;        
        var systems = [for(i in 0...make) new SystemTest1()];
        engine.addSystems(systems);
        assertEquals(systems.length,engine.systems.length);

        // add again
        for(s in systems)
            engine.addSystems([s]);
        assertEquals(systems.length,engine.systems.length);

        // remove no systems
        engine.removeSystems([]);
        assertEquals(systems.length,engine.systems.length);

        // remove some systems
        var remove = 3;
        engine.removeSystems([for(i in 0...remove)systems[i]]);
        assertEquals(systems.length - remove,engine.systems.length);

        // remove all
        engine.removeSystems(systems);
        assertEquals(0,engine.systems.length);       

    }

    public function testMatching(){

        var engine = new Engine();

        var make = 7;
        var entities = new Array<Entity>();
        for(i in 0...make)
            entities.push(engine.newEntity([ComponentTest1,ComponentTest2]));
        var system1 = new SystemTest1();
        engine.addSystems([system1]);

        // simple count
        engine.update();
        assertEquals(entities.length,SystemTest1.count);
        SystemTest1.count = 0;
        
        // double count
        for(i in 0...entities.length)
            entities.push(engine.newEntity([ComponentTest1,ComponentTest2,ComponentTest3]));
        engine.update();
        assertEquals(entities.length,SystemTest1.count);
        SystemTest1.count = 0;

        // double systems
        var system2 = new SystemTest1();
        engine.addSystems([system2]);
        engine.update();
        assertEquals(entities.length * 2,SystemTest1.count);
        SystemTest1.count = 0;

        // modify components        
        for(e in entities)
            engine.removeComponents(e,[ComponentTest1]);
        engine.update();
        assertEquals(0,SystemTest1.count);
        SystemTest1.count = 0;
        
        // modify components        
        for(e in entities)
            engine.addComponents(e,[ComponentTest1]);
        engine.update();
        assertEquals(entities.length * 2,SystemTest1.count);
        SystemTest1.count = 0;

        // remove system
        engine.removeSystems([system1]);
        engine.update();
        assertEquals(entities.length,SystemTest1.count);
        SystemTest1.count = 0;

    }

}