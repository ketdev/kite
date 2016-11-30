package tests;

import haxe.unit.TestCase;

import kite.Kite;
import kite.DataEntity;
import kite.Flow;
import kite.IComponent;
import kite.INode;


class Path implements IComponent{
    public var value:String;
}
class Directory implements IComponent{
    public var path:String;    
}
class Filename implements IComponent{
    public var name:String;
    public var ext:String;
}

class Source implements INode{
    public function new(){}
    function update(kite:Kite){
        trace('SOURCE');

        // create new data
        var d = kite.data([Path]);
        
        // set data path
        d.select(Path).value = 'C:/Xhi/Art/Misc/Mononoke.png';
    }
}
class Split implements INode{
    public function new(){}
    function update(kite:Kite, path:Path, data:DataEntity){
        trace('SPLIT ${path.value}');

        // create 2 data entities
        var dr = kite.data([Directory]);
        var fd = kite.data([Filename]);

        dr.select(Directory).path = haxe.io.Path.directory(path.value);
        var filename = haxe.io.Path.withoutDirectory(path.value);
        fd.select(Filename).name = haxe.io.Path.withoutExtension(filename);
        fd.select(Filename).ext = haxe.io.Path.extension(filename);

        // sink path data entity
        data.destroy();
    }
}

class Sink implements INode{
    public function new(){}
    function update(data:DataEntity){
        trace('SINK: $data');
        data.destroy();
    }
}


class FlowTests extends TestCase{
    
    public function testBasic(){

        // create data flow
        var flow = Kite.flow([new Source(), new Split(), new Sink()]);
        trace('Flow: ${flow}');
        

        flow.execute();

        trace('end of test');
        
        assertEquals(0,0);
    }
}