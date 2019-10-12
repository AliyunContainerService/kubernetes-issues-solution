Orphaned Pod is one pod which is terminating and should be clean up.

## Description

      Dec 25 16:44:48 iZ2ze65lci9pegg2wr99g9Z kubelet: E1225 16:44:48.581657   21207 kubelet_volumes.go:140] Orphaned pod "06fa705f-0821-11e9-8cd4-00163e1071ed"
      found, but volume paths are still present on disk : There were a total of 2 errors similar to this. Turn up verbosity to see them.


## Reproduce


## How to Fix
New kubernetes release fix some issues on this.
