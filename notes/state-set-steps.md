# StateSet steps

how creating and applying a StateSet should happen.

a StateSet is a set of (adapter, key, directive, value) tuples.
    
    {
      'defaults': [
        {
          'key': 'k',
          '<set | unset | array_contains':
        }
      ]
    }

1.  read and store (in the StateSet object) the current value for all keys.
    
2.  see if the any of the values should be changed. if there are no changes needed, return.

3.  change the needed values on the ruby object represntation. this will raise errors if clobber / create have problems.

4.  iterate through each value that was changed and attempt the write through the adapter.

5.  if any write produces an error, try to write the values that have been changed back to their original value. if this produces an error, leave them and report the problems.

6.  
