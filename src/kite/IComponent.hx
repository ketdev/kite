package kite;

/**
    Components automatically define a private __uid__ method that returns 
    an Int with a unique value for each component type.
**/
@:autoBuild(kite.macro.MakeComponent.generate())
interface IComponent {}