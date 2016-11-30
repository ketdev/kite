package kite;

class Kite{

    /**
        Create a new data execution flow.
        Added nodes are executed in order of addition.
        During flow execution, the nodes cannot be modified.
    **/
    public static function flow(?nodes:Array<kite.INode>):kite.Flow{
        var kite = new kite.Kite();
        var flow = new kite.Flow(kite);
        kite._flow = flow; // link back
        if(nodes != null) flow.push(nodes);
        return flow;
    }
    
    /**
        Create a new data entity.
        Data objects are pooled and reused.
    **/
    public function data(?components:Array<Class<kite.IComponent>>):kite.DataEntity{
        var dataIndex = _flow._dataPool.alloc();
        var data = _flow._dataPool.get(dataIndex);
        data._active = true;
        data.add(components);
        return data;
    }


    public function toString():String{
        return 'Kite';
    }
    
    private function new(){}
    private var _flow:kite.Flow; // current flow

}