package kite.internal.sugar;

@:allow(kite.internal.Internal)
abstract ComponentIndex(Int) from Int to Int{
    private function new(uid:Int){ 
        this = uid; 
    }
}