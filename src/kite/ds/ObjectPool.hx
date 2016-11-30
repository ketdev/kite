package kite.ds;

import haxe.ds.Vector;

class ObjectPoolIterator {
    private var _iterable:Vector<Int>;
    private var _length:Int;
    private var _index = 0;
    public function new(iterable:Vector<Int>, length:Int){
        _iterable = iterable;
        _length = length;
    }
    public function hasNext():Bool{
        return _index < _length;
    }
    public function next():Int {
        return _iterable[_index++];
    }
}

class ObjectPool<T>{

    public static inline var InitialCapacity = 32;

    private var _allocator:Int->T;
	private var _pool:Vector<T>;
    private var _next:Vector<Int>;
    private var _holder:Vector<Int>;

    public var length(default,null):Int = 0;

    public function new(allocator:Int->T, capacity:UInt = InitialCapacity){
        _allocator = allocator;
        // Preallocate pool
        _pool = new Vector<T>(capacity);
        for(index in 0..._pool.length)
            _pool.set(index,_allocator(index));
        // Build next index map
        _next = new Vector<Int>(capacity);  
        for(index in 0..._pool.length)
            _next.set(index,index);    
        // Build holder index map
        _holder = new Vector<Int>(capacity);  
        for(index in 0..._pool.length)
            _holder.set(index,index);   
    }
    
    public function alloc():Int {        
        // Check if out of memory, need to reallocate bigger buffer
        if(length == _pool.length){
            // Expand pool
            var old = _pool;
            _pool = new Vector<T>(old.length << 1);
            for(index in old.length..._pool.length)
                _pool.set(index,_allocator(index));    
            Vector.blit(old,0,_pool,0,old.length);
            // Expand next
            var old = _next;
            _next = new Vector<Int>(old.length << 1);
            for(index in old.length..._pool.length)
                _next.set(index,index);     
            Vector.blit(old,0,_next,0,old.length);
            // Expand holder
            var old = _holder;
            _holder = new Vector<Int>(old.length << 1);
            for(index in old.length..._pool.length)
                _holder.set(index,index);     
            Vector.blit(old,0,_holder,0,old.length);
        }

        // Get next free entity
        var index = _next[length]; // get the index to add 

        length++; // register allocation
        return index;
    }
    
    @:arrayAccess public function get(index:Int):T {
        if(index >= _pool.length || _holder[index] >= length || index < 0) // out of bounds
            return null;
        return _pool.get(index);
    }
    @:arrayAccess public function set(index:Int, value:T):T {
        if(index >= _pool.length || _holder[index] >= length || index < 0) // out of bounds
            return null;
        return _pool.set(index,value);
    }

    public function free(index:Int) {
        // aready removed if holder is not within count
        if(index >= _pool.length || _holder[index] >= length || index < 0) // out of bounds
            return;    

        // pop
        length--;

        var keep = _next[length];  // what should we keep?
        var slot = _holder[index]; // where can we keep it?

        // swap removed and kept, to fill hole
        _next[length] = index;   // index removed (outside)
        _next[slot] = keep;      // keep on inside slot
        _holder[keep] = slot;    // correct holders
        _holder[index] = length; // correct holders
    }
    public function iterator():Iterator<Int>{
        return new ObjectPoolIterator(_next,length);
    }

    public function reset(){
        length = 0;
        for(index in 0..._pool.length){
            _next.set(index,index);   
            _holder.set(index,index);
        }
    }

    public function last():Int{
        if(length == 0) 
            return -1;
        return _next[length-1];
    }

    public function push(value:T):Int {
        var i = alloc();
        set(i,value);
        return i;
    }
    public function pop():T {
        var i = last();
        if(i < 0) return null;
        var value = get(i);
        free(i);
        return value;
    }

}