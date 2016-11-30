#if macro
package kite.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class UidMeta{
    
    private static var _componentUid:Int = 0;
    private static var _systemUid:Int = 0;
    private static var _subscribed:Bool = false;
    
    macro public static function add():Array<Field> {
        // Subscribe to generate event once only
        if(!_subscribed){
            _subscribed = true;
            Context.onGenerate(_enumerate);
        }

        // Add UID metadata
        var ct:ClassType = Context.getLocalClass().get();
        ct.meta.remove('kite_uid');
        for (intf in ct.interfaces){
            if(intf.t.toString() == 'kite.IComponent'){
                ct.meta.add('kite_uid', [macro $v{ _componentUid }], Context.currentPos());
                #if debug trace('Component $_componentUid => ${ct.name}'); #end
                _componentUid++;
                break;
            }
            if(intf.t.toString() == 'kite.INode'){
                ct.meta.add('kite_uid', [macro $v{ _systemUid }], Context.currentPos());
                #if debug trace('Node $_systemUid => ${ct.name}'); #end
                _systemUid++;
                break;
            }
        }

        return Context.getBuildFields();
    }
    
    private static function _enumerate(types:Array<haxe.macro.Type>):Void {
        var components = new Array<String>();
        var systems = new Array<String>();
        for (type in types) {
            switch (type) {
            case TInst(rt, _):
                var t = rt.get(); 
                while (t!=null) {
                    for (intf in t.interfaces){
                        if(intf.t.toString() == 'kite.IComponent'){
                            components.push(rt.toString());
                            break;
                        }
                        if(intf.t.toString() == 'kite.INode'){
                            systems.push(rt.toString());
                            break;
                        }
                    }
                    t = if (t.superClass!=null) t.superClass.t.get() else null;
                }
            default:
            }
        }
        // set result count as metadata on engine
        var ct:ClassType = null;
        switch (Context.getType('kite.Flow')) {
            case TInst(classType, _):
                ct = classType.get();
            default:
        }
        ct.meta.remove('kite_components');
        ct.meta.remove('kite_nodes');
        ct.meta.add('kite_components', [macro $v{ components }], Context.currentPos());
        ct.meta.add('kite_nodes', [macro $v{ systems }], Context.currentPos());
    }

}

#end