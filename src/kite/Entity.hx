package kite;

@:allow(kite.internal.Internal)
abstract Entity(Int) from Int to Int{
    // Each entity is an index on the engine's entity pool
    private function new(uid:Int){ 
        this = uid; 
    }
}