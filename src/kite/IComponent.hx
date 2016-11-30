package kite;

/**
    Data Components

    Note: components are pooled, created by calling the default 
    constructor (or empty if doesn't have), and reused between
    data entities. Always set the value of the component when
    adding a new component to a data entity. 
**/
@:autoBuild(kite.macro.UidMeta.add())
interface IComponent {}