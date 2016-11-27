package tests;

import haxe.unit.TestRunner;
import tests.ObjectPoolTests;
import tests.EngineTests;

class All{
    public static function run(){
        var r = new TestRunner();
        r.add(new ObjectPoolTests());
        r.add(new EngineTests());
        // ...

        // run all tests
        r.run();
    }
}