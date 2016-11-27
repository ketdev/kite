package kite.internal.sugar;

@:allow(kite.internal.Internal)
abstract SystemIndex(Int) from Int to Int{
    private function new(i:Int){ 
        this = i; 
    }
}