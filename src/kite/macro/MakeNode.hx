
package kite.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import Type in RType;
using Lambda;

@:keep
typedef Requirement = {    
    var kiteIndex:Int;
    var dataIndex:Int;
    var components:Array<String>;
    //var optionals:Array<String>;
}

class MakeNode{
    
    private static inline var UpdateMethod = 'update';
    private static inline var InvokeMethod = '__kite_invoke__';

    macro public static function make():Array<Field> {
        var fields = Context.getBuildFields();
        var name = Context.getLocalClass().toString();
        
        // get injection arguments
        var req = getRequirements(fields);

        // Add requirements as node metadata
        var ct:ClassType = Context.getLocalClass().get();
        ct.meta.remove('kite_requirements');
        ct.meta.add('kite_requirements', [macro $v{ req }], Context.currentPos());

        var exprString = 'update(';
        var length = req.components.length + (req.dataIndex >= 0 ? 1 : 0) + (req.kiteIndex >= 0 ? 1 : 0);
        var offset = 0;
        for(i in 0...length){
            if(i > 0) exprString += ',';
            if(i == req.kiteIndex){
                exprString += 'kite';
                offset++;
            }
            else if(i == req.dataIndex){
                exprString += 'data';
                offset++;
            }else{
                exprString += 'cast args[${i-offset}]';
            }
        }
        exprString += ')';

        //#if debug trace('$name => $exprString'); #end

        // Create internal update method with correct mapping
        fields.push({
            name: InvokeMethod,
            access: [APrivate],
            meta: [{
                name: ':keep',
                pos: Context.currentPos()
            }],
            kind: FFun({
                ret  : macro:Void,
                expr: Context.parseInlineString(exprString,Context.currentPos()),
                args : [{
                    name: 'kite',
                    type: macro:kite.Kite 
                },
                {
                    name: 'data',
                    type: macro:kite.DataEntity 
                },
                {
                    name: 'args',
                    type: macro:haxe.ds.Vector<kite.IComponent> 
                }]
            }),
            pos: Context.currentPos()
        });

        return fields;
    }

    private static function getRequirements(fields:Array<Field>):Requirement{
        var name = Context.getLocalClass().toString();

        // get update method
        var method = fields.find(function(f) return f.name == UpdateMethod);
        
        // Add flow access
        method.meta.push({
            name: ':access',
            params: [macro $v{ 'kite.Flow' }],
            pos: Context.currentPos()
        });
        
        // Check access fields
        var isPublic = false;
        for(a in method.access){
            switch(a){
                case AStatic:
                    Context.error('$name.$UpdateMethod(...) cannot be static', Context.currentPos());
                case AMacro:
                    Context.error('$name.$UpdateMethod(...) cannot be a macro', Context.currentPos());
                case _: // APublic|APrivate|AOverride|ADynamic|AInline
            }
        }
        
        // Make sure it's a function
        var args:Array<FunctionArg>;
        switch(method.kind){
            case FFun(func):
                args = func.args;
            default: // FVar|FProp
                Context.error('$name.$UpdateMethod(...) must be a function', Context.currentPos());
        }

        // dependency injection
        var inject:Requirement = {
            kiteIndex: -1,
            dataIndex: -1,
            components: new Array<String>(),            
            //optionals: new Array<String>()
        }
        
        // check arguments
        for(i in 0...args.length){
            var arg = args[i];
            var type = Context.resolveType(arg.type, Context.currentPos());

            // Make sure it's a class instance
            var classtype:ClassType;
            var classname:String;
            while(type != null){
                switch (type) {
                    case TType(t, _): // class typedef
                        type = t.get().type;
                        continue;
                    case TInst(t, params): // class instace
                        classtype = t.get();
                        classname = t.toString();
                        // disable class params
                        if(params.length > 0)
                            Context.error('Argument `${arg.name}` for $name.$UpdateMethod(...) cannot have type parameters', Context.currentPos());
                    case _:
                        Context.error('Argument `${arg.name}` for $name.$UpdateMethod(...) must be a class.', Context.currentPos());
                }
                break;
            }
               
            var isValid = false;

            // check if it's kite
            if( !isValid && classname == 'kite.Kite' ){
                if(inject.kiteIndex >= 0)
                    Context.error('Duplicate `kite.Kite` dependencies for $name.$UpdateMethod(...)', Context.currentPos());
                inject.kiteIndex = i;
                isValid = true;
            }

            // check if it's data
            if( !isValid && classname == 'kite.DataEntity' ){
                if(inject.dataIndex >= 0)
                    Context.error('Duplicate `kite.DataEntity` dependencies for $name.$UpdateMethod(...)', Context.currentPos());
                inject.dataIndex = i;
                isValid = true;
            }

            // check if it's component
            // var isComponent:Bool = false;
            // while (classtype!=null && !isComponent) {
            //     for (intf in classtype.interfaces)
            //         if(intf.t.toString() == 'kite.IComponent')   
            //             isComponent = true;
            //     classtype = if (classtype.superClass!=null) classtype.superClass.t.get() else null;
            // }

            // must directly implement IComponent
            var isComponent = classtype.interfaces.exists(function(t) return t.t.toString() == 'kite.IComponent');


            if(!isValid && !isComponent)
                Context.error('Type `${classname}` used in $name.$UpdateMethod(...) must implement kite.IComponent', Context.currentPos());

            // add component
            if(isComponent){                
                // Don't allow two components of same type
                if(inject.components.has(classname) /* || inject.optionals.has(classname) */)
                    Context.error('Duplicate component type `${classname}` for $name.$UpdateMethod(...)', Context.currentPos());
            
                if(arg.opt) //inject.optionals.push(classname);
                    Context.error('Argument `${arg.name}` for $name.$UpdateMethod(...) cannot be optional', Context.currentPos()); 
                else
                    inject.components.push(classname);
            }
        }

        return inject;
    }

}
#if macro

#end