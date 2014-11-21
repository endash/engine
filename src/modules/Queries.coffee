### Input: DOM Queries

 - Listens for changes in DOM,
 - Invalidates cached DOM Queries
   by bruteforcing combinators on reachable elements

 Input:  MutationEvent, processes observed mutations
 Output: Expressions, revaluates expressions

 State:  - `@[path]`: elements and collections by selector path
         - `@watchers[id]`: dom queries by element id 
###

class Queries
  constructor: (@engine) ->
    @watchers = {}
    @mutations = []

  onBeforeSolve: ->
    # Update all DOM queries that matched mutations
    index = 0
    while @mutations[index]
      watcher = @mutations.splice(0, 3)
      @engine.document.solve watcher[0], watcher[1], watcher[2]
      
    # Execute all deferred selectors (e.g. comma)
    index = 0
    if @ascending
      while @ascending[index]
        contd = @ascending[index + 1]
        collection = @[contd]
        if old = @engine.updating?.collections?[contd]
          collection = collection.slice()
          collection.isCollection = true
          for item, i in collection by -1
            if old.indexOf(item) > -1
              collection.splice(i, 1)
        if collection?.length
          op = @ascending[index]
          @engine.document.Command(op).ascend(@engine.document, op, contd, @ascending[index + 2], collection)
        index += 3
      @ascending = undefined
    @

  addMatch: (node, continuation) ->
    return unless node.nodeType == 1
    if (index = continuation.indexOf(@engine.Continuation.DESCEND)) > -1
      continuation = continuation.substring(index + 1)
    continuation = @engine.Continuation.getCanonicalSelector(continuation)
    node.setAttribute('matches', (node.getAttribute('matches') || '') + ' ' + continuation.replace(/\s+/, @engine.Continuation.DESCEND))
  
  removeMatch: (node, continuation) ->
    return unless node.nodeType == 1
    if matches = node.getAttribute('matches')
      if (index = continuation.indexOf(@engine.Continuation.DESCEND)) > -1
        continuation = continuation.substring(index + 1)
      path = ' ' + @engine.Continuation.getCanonicalSelector(continuation)
      if matches.indexOf(path) > -1
        node.setAttribute('matches', matches.replace(path,''))

  # Manually add element to collection, handle dups
  # Also stores path which can be used to remove elements
  add: (node, continuation, operation, scope, key, contd) ->
    collection = @[continuation] ||= []

    if !collection.push
      return
    collection.isCollection = true

    keys = collection.continuations ||= []
    paths = collection.paths ||= []
    scopes = collection.scopes ||= []


    @snapshot continuation, collection

    if (index = collection.indexOf(node)) == -1
      for el, index in collection
        break unless @comparePosition(el, node, keys[index], key)
      collection.splice(index, 0, node)
      keys.splice(index, 0, key)
      paths.splice(index, 0, contd)
      scopes.splice(index, 0, scope)
      @chain collection[index - 1], node, continuation
      @chain node, collection[index + 1], continuation
      if operation.parent.name == 'rule'
        @addMatch(node, continuation)

      return true
    else unless scopes[index] == scope && paths[index] == contd
      duplicates = (collection.duplicates ||= [])
      for dup, index in duplicates
        if dup == node
          if scopes[index] == scope && paths[index] == contd # && keys[index] == key
            return
      duplicates.push(node)
      keys.push(key)
      paths.push(contd)
      scopes.push(scope)
      return

      
    return collection

  # Return collection by path & scope
  get: (operation, continuation, old) ->
    if typeof operation == 'string'
      result = @[operation]
      return result

  # Remove observers from element
  unobserve: (id, continuation, quick, path, contd, scope, top) ->
    if continuation != true
      refs = @engine.Continuation.getVariants(continuation)
    index = 0
    return unless (watchers = typeof id == 'object' && id || @watchers[id])
    while watcher = watchers[index]
      query = watchers[index + 1]
      if refs && 
          (refs.indexOf(query) == -1 || 
          (scope && scope != watchers[index + 2]) ||
          (top && @engine.Command.getRoot(watcher) != top))
        index += 3
        continue
      if path
        parent = watcher
        matched = false
        while parent
          if parent.path == path
            matched = true
            break
          parent = parent.parent
        unless matched
          index += 3
          continue 

      subscope = watchers[index + 2]
      watchers.splice(index, 3)
      if !quick
        @clean(watcher, query, watcher, subscope, true, contd ? query)
    if !watchers.length && watchers == @watchers[id]
      delete @watchers[id] 

  filterByScope: (collection, scope, operation, top)->
    return collection unless collection?.scopes
    length = collection.length
    result = []
    if operation
      operation = @engine.Command.getRoot(operation)
    for s, index in collection.scopes
      if s == scope
        if operation && collection.continuations
          top = @engine.Command.getRoot(collection.continuations[index])
          continue unless top == operation
        if index < length
          value = collection[index]
        else
          value = collection.duplicates[index - length]
        if result.indexOf(value) == -1
          result.push(value)
    return result

  snapshot: (key, collection) ->
    return if (collections = @engine.updating.collections ||= {}).hasOwnProperty key

    if collection?.push
      c = collection.slice()
      if collection.isCollection
        c.isCollection = true
      if collection.duplicates
        c.duplicates = collection.duplicates.slice()
      if collection.scopes
        c.scopes = collection.scopes.slice()
      if collection.continuations
        c.continuations = collection.continuations.slice()

      collection = c
      
    collections[key] = collection
    

  # Remove element from collection needlely
  removeFromCollection: (node, continuation, operation, scope, needle, contd) ->
    collection = @get(continuation)
    length = collection.length
    keys = collection.continuations
    paths = collection.paths
    scopes = collection.scopes
    duplicate = null

    #if !contd?
    #  refs = [undefined]
    #else
    refs = @engine.Continuation.getVariants(contd)
    # Dont remove it if element matches more than one selector
    if (duplicates = collection.duplicates)
      for dup, index in duplicates
        if dup == node
          if refs.indexOf(paths[length + index]) > -1 &&
              #(keys[length + index] == needle) &&
              scopes[length + index] == scope

            @snapshot continuation, collection
            duplicates.splice(index, 1)
            keys.splice(length + index, 1)
            paths.splice(length + index, 1)
            scopes.splice(length + index, 1)
            return false
          else
            duplicate ?= index

    if operation && length && needle?
      @snapshot continuation, collection

      if (index = collection.indexOf(node)) > -1
        # Fall back to duplicate with a different key
        if keys
          negative = false#if refs then null else false
          return null if scopes[index] != scope
          return null if refs.indexOf(paths[index]) == -1
          #return null if keys[index] != needle
          if duplicate?
            duplicates.splice(duplicate, 1)
            paths[index] = paths[duplicate + length]
            paths.splice(duplicate + length, 1)
            keys[index] = keys[duplicate + length]
            keys.splice(duplicate + length, 1)
            scopes[index] = scopes[duplicate + length]
            scopes.splice(duplicate + length, 1)
            return false

        collection.splice(index, 1)
        if keys
          keys.splice(index, 1)
          paths.splice(index, 1)
          scopes.splice(index, 1)
        @chain collection[index - 1], node, continuation
        @chain node, collection[index], continuation
        if operation.parent.name == 'rule'
          @removeMatch(node, continuation)
        return true



  # Remove observers and cached node lists
  remove: (id, continuation, operation, scope, needle = operation, recursion, contd = continuation) ->
    if typeof id == 'object'
      node = id
      id = @engine.identity.yield(id)
    else
      if id.indexOf('"') > -1
        node = id
      else
        node = @engine.identity[id]

    if continuation

      collection = @get(continuation)

      if collection && @engine.isCollection(collection)
        @snapshot continuation, collection
      
        removed = @removeFromCollection(node, continuation, operation, scope, needle, contd)
        
      else
        removed = undefined

      if removed != false
        @engine.pairs.remove(id, continuation)

        if parent = operation?.parent
          if @engine.isCollection(collection)
            string = continuation + id
          else
            string = continuation
          parent.command.release?(node, @engine, operation, string, scope)
          
      
        # Remove all watchers that match continuation path
        ref = continuation + (collection?.length? && id || '')

        if ref.charAt(0) == @engine.Continuation.PAIR
          @unobserve(id, ref, undefined, undefined, ref, scope)
        else
          @unobserve(id, ref, undefined, undefined, ref)

        if recursion != continuation
          if removed != false #true#(removed || !parent?.command.release)
            @updateCollections operation, continuation, scope, recursion, node, continuation, contd
          if removed
            @clean(continuation + id)

    else if node
      # Detach queries attached to an element when removing element by id
      @unobserve(id, true)

    return removed


  clean: (path, continuation, operation, scope, bind, contd) ->
    if command = path.command
      path = (continuation || '') + (operation.uid || '') + (command.selector || command.key || '')
    continuation = path if bind
    result = @get(path)
    
    if (result = @get(path, undefined, true)) != undefined
      @each 'remove', result, path, operation, scope, operation, false, contd

    #if scope && operation.command.cleaning
    #  @remove @engine.identity.find(scope), path, operation, scope, operation, undefined, contd
    
    @engine.solved.remove(path)
    @engine.intrinsic.remove(path)
    @engine.stylesheets?.remove(path)

    shared = false
    if @engine.isCollection(result)
      if result.scopes
        for s, i in result.scopes
          # fixme
          if s != scope || (operation && result.continuations[i] != operation)
            shared = true
            break

    if !shared
      @set path, undefined

    # Remove queries in queue and global watchers that match the path 
    if @mutations
      @unobserve(@mutations, path, true)


    @unobserve((scope || @engine.scope)._gss_id, path)

    if !result || !@engine.isCollection(result)
      unless path.charAt(0) == @engine.Continuation.PAIR
        contd = @engine.Continuation(path)
        @engine.updating?.remove(contd)
        @engine.yield(['remove', contd])
    return true

  # If a query selects element from some other node than current scope
  # Maybe somebody else calculated it already
  fetch: (args, operation, continuation, scope) ->
    node = if args[0]?.nodeType == 1 then args[0] else scope
    query = operation.command.getPath(@engine, operation, node)
    return @engine.updating?.queries?[query]

  chain: (left, right, continuation) ->
    if left
      @match(left, ':last', '*', undefined, continuation)
      @match(left, ':next', '*', undefined, continuation)
    if right
      @match(right, ':previous', '*', undefined, continuation)
      @match(right, ':first', '*', undefined, continuation)

  updateCollections: (operation, path, scope, added, removed, recursion, contd) ->
    
    oppath = @engine.Continuation.getCanonicalPath(path)
    if path == oppath || @engine.Continuation.PAIR + oppath == path

    else if recursion != oppath
      @updateCollection operation, oppath, scope, added, removed, oppath, path

    @updateCollection operation, path, scope, added, removed, recursion, contd || ''
    
  # Combine nodes from multiple selector paths
  updateCollection: (operation, path, scope, added, removed, recursion, contd) ->
    if removed
      @each 'remove', removed, path, operation, scope, operation, recursion, contd

    if added
      @each 'add', added, path, operation, scope, operation, contd

    if (collection = @[path])?.continuations
      sorted = collection.slice().sort (a, b) =>
        i = collection.indexOf(a)
        j = collection.indexOf(b)
        return @comparePosition(a, b, collection.continuations[i], collection.continuations[j]) && -1 || 1
      

      updated = undefined
      for node, index in sorted
        if node != collection[index]
          if !updated
            updated = collection.slice()
            if @[path]
              @[path] = updated
            updated.continuations = collection.continuations.slice()
            updated.paths = collection.paths.slice()
            updated.scopes = collection.scopes.slice()
            updated.duplicates = collection.duplicates
            updated.isCollection = collection.isCollection
            updated[index] = node
          i = collection.indexOf(node)
          updated[index] = node
          updated.continuations[index] = collection.continuations[i]
          updated.paths[index] = collection.paths[i]
          updated.scopes[index] = collection.scopes[i]

          @chain sorted[index - 1], node, path
          @chain node, sorted[index + 1], path

  # Perform method over each node in nodelist, or against given node
  each: (method, result = undefined, continuation, operation, scope, needle, recursion, contd) ->
    if @engine.isCollection(result)
      copy = result.slice()
      returned = undefined
      for child in copy
        if @[method] child, continuation, operation, scope, needle, recursion, contd
          returned = true
      return returned
    else if typeof result == 'object'
      return @[method] result, continuation, operation, scope, needle, recursion, contd

  # Filter out known nodes from DOM collections
  update: (args, result = undefined, operation, continuation, scope) ->
    engine = @engine
    updating = engine.updating
    path = operation.command.getPath(engine, operation, continuation)
    old = @get(path)

    # Normalize query to reuse results
    command = operation.command

    node = if args[0]?.nodeType == 1 then args[0] else scope

    if !command.relative && !command.marked && 
            (query = operation.command.getPath(engine, operation, node, scope)) && 
            updating.queries?.hasOwnProperty(query)
      result = updating.queries[query]
    if updating.collections?.hasOwnProperty(path)
      old = updating.collections[path]
    else if !old? && (result && result.length == 0) && continuation
      old = @get(engine.Continuation.getCanonicalPath(path))

    isCollection = engine.isCollection(result)

    # Clean refs of nodes that dont match anymore
    if old
      if engine.isCollection(old)
        if continuation?.charAt(0) == engine.Continuation.PAIR
          old = @filterByScope(old, scope, operation)
        removed = undefined
        for child, index in old
          if !old.scopes || old.scopes?[index] == scope
            if !result || Array.prototype.indexOf.call(result, child) == -1
              (removed ||= []).push child
      else if result != old
        if !result
          removed = old
        @clean(path, undefined, operation, scope)
      else if continuation.charAt(0) == engine.Continuation.PAIR

        # Subscribe node to the query
        if id = engine.identity.yield(node)
          watchers = @watchers[id] ||= []
          if (engine.indexOfTriplet(watchers, operation, continuation, scope) == -1)
            operation.command.prepare(operation)
            watchers.push(operation, continuation, scope)
        
        return old
      else
        return

    # Register newly found nodes
    if isCollection
      @[path] ||= []
      added = undefined
      for child in result
        if !old || Array.prototype.indexOf.call(old, child) == -1  
          (added ||= []).push child
          added.isCollection = true

      # Snapshot live node list for future reference
      if result && result.item
        result = Array.prototype.slice.call(result, 0)
    else
      added = result 
      removed = old

    if result?.continuations
      @updateCollections(operation, path, scope, undefined, undefined, undefined, continuation)
    else
      @updateCollections(operation, path, scope, added, removed, undefined, continuation)
      
    #unless operation.def.capture
      # Subscribe node to the query
    if id = engine.identity.yield(node)
      watchers = @watchers[id] ||= []
      if (engine.indexOfTriplet(watchers, operation, continuation, scope) == -1)
        operation.command.prepare(operation)
        watchers.push(operation, continuation, scope)
    
    if query
      @snapshot query, old
      (@engine.updating.queries ||= {})[query] = result

    @snapshot path, old

    return if result == old

    unless result?.push
      @set path, result

    return added

  set: (path, result) ->
    old = @[path]
    if !result?
      @snapshot path, old
    if result
      @[path] = result
    else
      delete @[path]
    @engine.pairs?.set(path, result)

    return

  # Check if a node observes this qualifier or combinator
  match: (node, group, qualifier, changed, continuation) ->
    return unless id = @engine.identity.yield(node)
    return unless watchers = @watchers[id]
    if continuation
      path = @engine.Continuation.getCanonicalPath(continuation)
    
    for operation, index in watchers by 3
      if groupped = operation.command[group]
        contd = watchers[index + 1]
        continue if path && path != @engine.Continuation.getCanonicalPath(contd)
        scope = watchers[index + 2]
        # Check qualifier value
        if qualifier
          @qualify(operation, contd, scope, groupped, qualifier)
        # Check combinator and tag name of a given element
        else if changed.nodeType
          @qualify(operation, contd, scope, groupped, changed.tagName, '*')
        # Check combinator and given tag name
        else if typeof changed == 'string'
          @qualify(operation, contd, scope, groupped, changed, '*')
        # Ditto in bulk: Qualify combinator with nodelist or array of tag names
        else for change in changed
          if typeof change == 'string'
            @qualify(operation, contd, scope, groupped, change, '*')
          else
            @qualify(operation, contd, scope, groupped, change.tagName, '*')
    @

  # Check if query observes qualifier by combinator 
  qualify: (operation, continuation, scope, groupped, qualifier, fallback) ->
    if (indexed = groupped[qualifier]) || (fallback && groupped[fallback])
      if @engine.indexOfTriplet(@mutations, operation, continuation, scope) == -1
        length = (continuation || '').length
        # Make shorter continuation keys run before longer ones
        for mutations, index in @mutations by 3
          if (@mutations[index + 1] || '').length > length
            break
        @mutations.splice(index, 0, operation, continuation, scope)
    @

  # temp workaround for inability to 
  getParentScope: (continuation, operation) ->
    @ScopeSplitterRegExp ||= new RegExp(@engine.Continuation.DESCEND + '|' + @engine.Continuation.ASCEND + '&', 'g')

    bits = continuation.split(@ScopeSplitterRegExp)
    
    if !bits[bits.length - 1]
      bits.pop()
    bits.pop()

    for bit, index in bits by -1
      parent = operation.parent
      canonical = @engine.Continuation.getCanonicalPath(bit)
      while parent = parent.parent
        if parent.name == 'rule' && parent[1].path == canonical
          break
      break if parent
      bits.splice index, 1

    continuation = bits.join(@engine.Continuation.DESCEND)
    if !continuation || 
        (bits.length == 1 && bits[0].indexOf('style[type*="text/gss"]') > -1)
      return @engine.scope
    if id = continuation.match(@engine.pairs.TrailingIDRegExp)
      if id[1].indexOf('"') > -1
        return id[1]
      return @engine.identity[id[1]]
    else
      return @engine.queries[continuation]

  getScopedCollection: (operation, continuation, scope) ->
    path = @engine.Continuation(@engine.Continuation.getCanonicalPath(continuation))
    collection = @get(path)
    #if operation[1].marked
    #  collection = @filterByScope collection, scope
    #else if operation[1].def.mark
    #collection = @filterByScope collection, @getParentScope(continuation, operation)
    return collection
    

  # Compare position of two nodes to sort collection in DOM order
  # Virtual elements make up stable positions within collection,
  # so dom elements can be permuted only within range between virtual elements
  comparePosition: (a, b, op1, op2) ->
    if op1 != op2
      parent = op1.parent
      i = parent.indexOf(op1)
      j = parent.indexOf(op2)
      if i > j
        left = op2
        right = op1
      else
        left = op1
        right = op2

      index = i
      while next = parent[++index]
        break if next == right
        if next[0] == '$virtual'
          return i < j

      unless a.nodeType && b.nodeType 
        return i < j
    if a.compareDocumentPosition
      return a.compareDocumentPosition(b) & 4
    return a.sourceIndex < b.sourceIndex
module.exports = Queries