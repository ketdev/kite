package kite.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using Lambda;

class MakeSystem{    
    
    macro public static function generate():Array<Field> {
        var fields = Context.getBuildFields();

        // validate update method, and get components
        var components = getComponents(fields);

        // create component list
        fields.push(generateRequires(components));

        // create a generic invoke method to inject components to the update method
        fields.push(generateInvoker(components));

        //#if debug trace('${Context.getLocalClass()} => $components'); #end

        return fields;
    }

#if macro

    private static inline var SystemMethod = 'update'; 
    private static inline var InvokeMethod = '__invoke';
    private static inline var RequiresMethod = '__requires';

    private static function fullTypeName(path:TypePath):String{
        var cpy = path.pack.copy();
        cpy.push(path.name);
        return cpy.join('.');
    }

    private static function getField(fields : Array<Field>, name : String):Field {
        for(f in fields)
            if(f.name == name)
                return f;
        return null;
    }

    private static function getComponents(fields : Array<Field>):Array<String> {        
        var field = getField(fields, SystemMethod);
        var classType = Context.getLocalClass().get();
        var className = Context.getLocalClass().toString();
        var classPos = Context.currentPos();
        var components = new Map<String,Bool>();

        // Check existance
        if(field == null)
            Context.error('$className must contain the `$SystemMethod` method, see ISystem', classPos);
        
        // Check access fields
        var isPublic = false;
        for(a in field.access){
            switch(a){
                case APublic:
                    isPublic = true;
                case APrivate:
                    isPublic = false;
                case AStatic:
                    Context.error('$className.$SystemMethod(...) cannot be static', classPos);
                case AMacro:
                    Context.error('$className.$SystemMethod(...) cannot be a macro', classPos);
                default: // AOverride|ADynamic|AInline
                    // ok
            }
        }
        if(!isPublic)          
            Context.error('$className.$SystemMethod(...) must be public', classPos);
        
        // Make sure it's a method
        switch(field.kind){
            case FFun(f):
                // Get arguments
                var args = f.args;
                if(args.length < 2)
                    Context.error('$className must at least have `kite.Engine` and `kite.Entity` as first two arguments', classPos);
                else{
                    // Check engine
                    var arg = args[0];
                    if(arg.opt)
                        Context.error('Engine argument `${arg.name}` for $className.$SystemMethod(...) cannot be optional', classPos); 
                    var isEntity = false;
                    switch (arg.type) {
                        case TPath(p):  
                            isEntity = typesMatch(
                                Context.toComplexType(Context.getType(fullTypeName(p))),
                                macro:kite.Engine
                            );
                        case _:
                    } 
                    if(!isEntity)
                        Context.error('First argument `${arg.name}` for $className.$SystemMethod(...) must be `kite.Engine`', classPos);

                    // Check entity
                    arg = args[1];
                    if(arg.opt)
                        Context.error('Entity argument `${arg.name}` for $className.$SystemMethod(...) cannot be optional', classPos); 
                    var isEntity = false;
                    switch (arg.type) {
                        case TPath(p):  
                            isEntity = typesMatch(
                                Context.toComplexType(Context.getType(fullTypeName(p))),
                                macro:kite.Entity
                            );
                        case _:
                    } 
                    if(!isEntity)
                        Context.error('First argument `${arg.name}` for $className.$SystemMethod(...) must be `kite.Entity`', classPos);
                }
                for(i in 2...args.length){
                    var arg = args[i];
                    if(arg.opt)
                        Context.error('Component `${arg.name}` for $className.$SystemMethod(...) cannot be optional', classPos);
                    switch (arg.type) {
                        case TPath(p):
                            if(p.params.length > 0)
                                Context.error('Component `${arg.name}` for $className.$SystemMethod(...) cannot have type parameters', classPos);
                            var type:Type = Context.getType(fullTypeName(p));
                            switch (type) {
                                case TInst(rt, _):
                                    var t = rt.get();
                                    var tname = rt.toString();
                                    if(components.exists(tname))
                                        Context.error('Duplicate component type `$tname` for $className.$SystemMethod(...)', classPos);                                    
                                    components[tname] = true;

                                    var implem:Bool = false;
                                    while (t!=null && !implem) {
                                        for (intf in t.interfaces){
                                            if(intf.t.toString() == 'kite.IComponent'){    
                                                implem = true;
                                                break;
                                            }
                                        }
                                        t = if (t.superClass!=null) t.superClass.t.get() else null;
                                    }
                                    if(!implem)
                                        Context.error('Type `$tname` used in $className.$SystemMethod(...) must implement kite.IComponent', classPos);     
                                default:
                                    Context.error('Component `${arg.name}` for $className.$SystemMethod(...) is not a class instance', classPos);
                            }
                        default:
                            Context.error('Component `${arg.name}` for $className.$SystemMethod(...) is not a class instance', classPos);
                    }
                } 
            default: // FVar|FProp
                Context.error('$className.$SystemMethod(...) must be a method', classPos);
        }
        return [for (i in components.keys()) i];
    }

    private static function generateInvoker(components:Array<String>): Field{
        var className = Context.getLocalClass().toString();
        
        var exprString = 'update(engine,entity,' + [for(i in 0...components.length) 'cast args[$i]'].join(',') + ')';
        
        var field:Field = {
            name: InvokeMethod,
            access: [APrivate],
            kind: FFun({
                ret  : macro:Void,
                expr : Context.parse(exprString,Context.currentPos()),
                args : [{
                    name: 'engine',
                    type: macro:kite.Engine 
                },
                {
                    name: 'entity',
                    type: macro:kite.Entity 
                },
                {
                    name: 'args',
                    type: macro:haxe.ds.Vector<kite.IComponent> 
                }]
            }),
            pos: Context.currentPos()
        };

        return field;
    }

    private static function generateRequires(components:Array<String>): Field{
        var className = Context.getLocalClass().toString();
                
        var exprString = 'return [' + [for(s in components) '$s'].join(', ') + ']';
        
        var field:Field = {
            name: RequiresMethod,
            access: [APrivate],
            kind: FFun({
                ret  : macro:Array<Class<kite.IComponent>>,
                expr : Context.parse(exprString,Context.currentPos()),
                args : []
            }),
            pos: Context.currentPos()
        };

        return field;
    }

    private static function typesMatch(t0:ComplexType, t1:ComplexType):Bool{
        var match = false;
        switch (t0) {
            case TPath(pt):
                switch (t1) {
                    case TPath(ept):
                        if(pt.name == ept.name && pt.pack.length == ept.pack.length){
                            match = true;
                            for(i in 0...pt.pack.length){
                                if(pt.pack[i] != ept.pack[i])
                                    match = false;
                            }
                        }
                    case _:
                }
            case _:
        }        
        return match;
    }

#end

}