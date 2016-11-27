package kite.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class MakeComponent{    
    
#if macro

    private static inline var ComponentTypename = 'kite.IComponent'; 
    private static inline var MapperTypename = 'kite.macro.ComponentMapper';

    private static var uid:Int = 0;

    private static var subscribed:Bool = false;

    macro public static function generate():Array<Field> {
        // Subscribe to generate event once only
        if(!subscribed){
            subscribed = true;
            Context.onGenerate(enumComponents);
        }

        // Add UID metadata
        var ct:ClassType = Context.getLocalClass().get();
        var uidMeta = Context.makeExpr(uid, Context.currentPos());
        ct.meta.remove('uid');
        ct.meta.add('uid', [uidMeta], Context.currentPos());

        // advance
        uid++;

        return Context.getBuildFields();
    }

    private static function enumComponents(types:Array<haxe.macro.Type>):Void {
        var list = new Array<String>();
        for (type in types) {
            switch (type) {
            case TInst(rt, _):
                var t = rt.get(); 
                while (t!=null) {
                    for (intf in t.interfaces){
                        if(intf.t.toString() == ComponentTypename){
                            list.push(rt.toString());
                            break;
                        }
                    }
                    t = if (t.superClass!=null) t.superClass.t.get() else null;
                }
            default:
            }
        }

        // set result count as metadata
        var ct:ClassType = null;
        switch (Context.getType(MapperTypename)) {
            case TInst(classType, _):
                ct = classType.get();
            default:
        }
        var listParam = Context.makeExpr(list, Context.currentPos());
        ct.meta.remove('list');
        ct.meta.add('list', [listParam], Context.currentPos());
    }

#end

}
