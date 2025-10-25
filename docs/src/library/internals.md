# Internals


## Initialization

```@docs
IJulia.init
```

## Messaging

```@docs
IJulia.Msg
IJulia.msg_header
IJulia.send_ipython
IJulia.recv_ipython
IJulia.set_cur_msg
IJulia.send_status
```


## Request handlers

```@docs
IJulia.connect_request
IJulia.execute_request
IJulia.shutdown_request
IJulia.interrupt_request
IJulia.inspect_request
IJulia.history_request
IJulia.complete_request
IJulia.kernel_info_request
IJulia.is_complete_request
```


## Event loop

```@docs
IJulia.eventloop
IJulia.waitloop
```


## IO

```@docs
IJulia.IJuliaStdio
IJulia.watch_stream
```


## Multimedia display

```@docs
IJulia.InlineDisplay
IJulia.InlineIOContext
IJulia.ipy_mime
IJulia.ijulia_mime_types
IJulia.ijulia_jsonmime_types
IJulia.limitstringmime
IJulia.israwtext
IJulia.display_dict
IJulia.display_mimejson
IJulia.display_mimestring
IJulia.register_mime
IJulia.register_jsonmime
```


## Jupyter

```@docs
IJulia.find_jupyter_subcommand
IJulia.launch
```


## Debugging

```@docs
IJulia.set_verbose
```


## Utility

```@docs
IJulia.num_utf8_trailing
IJulia.get_token
IJulia.get_previous_token
```

## JSONX

```@docs
IJulia.JSONX.json
IJulia.JSONX.parse
IJulia.JSONX.parsefile
```
