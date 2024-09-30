configuration HashTableC{
   provides interface HashTable;
}

implementation{
   components HashTableP;
   HashTable = HashTableP.HashTable;

   HashTable = HashTableP.Flooding;
}