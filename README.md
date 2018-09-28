# ardupilog
An Ardupilot log to MATLAB converter. Primarily intended to facilitate processing of logs under MATLAB environment.

## Supported log formats
Currently, only Dataflash logs (.bin files) are supported.

## Usage
Add the `ardupilog` source code to your path.
Then,
```matlab
log = Ardupilog()
```
will open a file browser, where you can select the log file you want to decode.

Alternatively, the path can be passed directly as a string:
```matlab
log = Ardupilog('<path-to-log-string>')
```

The variable struct `log` will be generated with the included message types as fields.
Each field is a variable of type `LogMsgGroup`.

Each `LogMsgGroup` under a log contains the following members:
* `type`: The message ID.
* `name`: The declared name string.
* `LineNo`: The message sequence numbers where messages of this type appear in the log.
* `TimeS`: The timestamps vector in seconds since boot time, for each message.
* One vector for each of the message fields, of the same length as the timestamps.

### Message Filter
You can optionally filter the log file for specific message types:
```matlab
log = Ardupilog('<path-to-log', <msgFilter>)
```

`msgFilter` can be:
* Either a vector of integers, representing the message IDs you want to convert.
* Or a cell array of strings. Each string is the literal name of the message type.

### Slicing
Typially, only a small portion of the flight log is of interest. Ardupilog supports *slicing* logs to a specific start-end interval with:
```matlab
sliced_log = log.getSlice([<start_value>, <end_vlaue>], <slice_type>)
```
* `sliced_log` is a deep copy of the original log, sliced to the desired limits.
* `slice_type` can be either `TimeUS` or `LineNo`.
* `<start-value>` and `<end_value>` are either microseconds since boot or message sequence indexes.

**Example**
```matlab
log_during_cruise = log.getSlice([t_begin_cruise, t_end_cruise], 'TimeUS')
```