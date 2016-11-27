package tests;

import haxe.unit.TestCase;
import kite.internal.ObjectPool;
import Math.random;

class ObjectPoolTests extends TestCase{

    public function testRandom(){

        var capacity = 500;
        var iterations = 1000;

        var pool = new kite.internal.ObjectPool(function(id:Int) return id);
        var result = new Map<Int,Bool>();
        var items = 0;

        for(it in 0...iterations){
            if(random() > items/capacity){
                var e = pool.alloc();
                var l = [for(i in pool) i];
                //trace('+$e, list: $l');
                result.set(e,true);
                items++;
            }else{
                var e = Std.int(random()*capacity);
                pool.free(e);
                var l = [for(i in pool) i];
                //trace('-$e, list: $l');
                result.set(e,false);            
            }
            
            // validate
            var e = [for(i in pool) i];
            var contains = function(a:Array<Int>,i:Int) {for(t in a){ if (t==i){ return true; } } return false;};
            for(i in result.keys()){
                assertEquals(result[i],contains(e,i));
            }
        }
    }

}