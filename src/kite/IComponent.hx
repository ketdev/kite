package kite;

/**
    Components automatically adds a uid metadata 
    with a unique value for each component type.
**/
@:autoBuild(kite.macro.MakeComponent.generate())
interface IComponent {}