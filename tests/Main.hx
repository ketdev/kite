package tests;

import haxe.unit.TestRunner;
import tests.FlowTests;
import tests.ObjectPoolTests;

class Main{
    public static function main(){        
        // run all tests
        var r = new TestRunner();
        r.add(new FlowTests());
        r.add(new ObjectPoolTests());
        // ...

        // run all tests
        r.run();
    }
}