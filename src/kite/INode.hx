package kite;

/**
    Every node should contain an 'update'.
    The method can optionally accept IComponents, Kite and Data and will be automatically injected.
    Return type is assumed to be Void, and is otherwise ignored.
**/
@:autoBuild(kite.macro.UidMeta.add())
@:autoBuild(kite.macro.MakeNode.make())
interface INode{}