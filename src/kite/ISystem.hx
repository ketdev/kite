package kite;

/**
    Every system should contain an 'update' method that accepts components.
    The required components are computed at compile time by the argument types.
    Return type is assumed to be Void, and is otherwise ignored.
**/
@:autoBuild(kite.macro.MakeSystem.generate())
interface ISystem{

    /**
        Invokes the update method with the correct component parameters.
        This method is provided by the build macro automatically.
        Attempting to implement will cause a compilation error.
    **/
    @:allow(kite.internal.Internal)
    private function __invoke(components:haxe.ds.Vector<kite.IComponent>): Void;

    /**
        This method returns the components and their order,
        of the components it expects to receive from each entity.
        This method is provided by the build macro automatically.
        Attempting to implement will cause a compilation error.
    **/
    @:allow(kite.internal.Internal)
    private function __requires():Array<Class<kite.IComponent>>;
}