# ardupilog
An Ardupilot log to MATLAB converter. Primarily intended to facilitate processing of logs under MATLAB environment.

It is very efficient: The time required to parse large logs is in the order of seconds.

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
* `typeNumID`: The message ID.
* `name`: The declared name string.
* `LineNo`: The message sequence numbers where messages of this type appear in the log.
* `TimeS`: The timestamps vector in seconds since boot time, for each message.
* One vector for each of the message fields, of the same length as the timestamps.

### Plotting
To plot a specific numerical data field from a specific message, you can enter:
```matlab
log.plot('<msgName>/<fieldName>');
```

The full command allows for passnig a Matlab-style line style and an existing Axes Handle to plot in.
Additionally, it always returns the Axes Handles it plots in:
```matlab
ah = log.plot('<msgName>/<fieldName>',<lineStyle>,<axesHandle>)
```

For example, to plot the `Pitch` field from the `AHR2` message in red, enter:
```matlab
log.plot('AHR2/Pitch', 'r');
```

### Message Filter
You can optionally filter the log file for specific message types:
```matlab
log_filtered = log.filterMsgs(<msgFilter>)
log_filtered = Ardupilog('<path-to-log', <msgFilter>)
```

`msgFilter` can be:
* Either a vector of integers, representing the message IDs you want to convert.
* Or a cell array of strings. Each string is the literal name of the message type.

### Slicing
Typically, only a small portion of the flight log is of interest. Ardupilog supports *slicing* logs to a specific start-end interval with:
```matlab
sliced_log = log.getSlice([<start_value>, <end_vlaue>], <slice_type>)
```
* `sliced_log` is a deep copy of the original log, sliced to the desired limits.
* `slice_type` can be either `TimeS` or `LineNo`.
* `<start-value>` and `<end_value>` are either sconds since boot or message sequence indexes.

**Example**
```matlab
log_during_cruise = log.getSlice([t_begin_cruise, t_end_cruise], 'TimeS')
```

### Exporting to plain struct
To parse and use the `log` object created by
```matlab
log = Ardupilog('<path-to-log>')
```
requires the `ardupilog` library to exist in the current MATLAB path.

Creating a more basic struct file, free of the `ardupilog` dependency, is possible with:
```matlab
log_struct = log.getStruct();
```
`log_struct` does not need the `ardupilog` source code accompanying it to be shared.

### Supported log versions
Logs from the following versions are been tested for Continuous Integration:
* Copter: 3.6.9, 4.0.0, 4.1.0
* Plane: 3.5.2, 3.7.1, 3.8.2, 3.9.9, 4.0.0, 4.1.0
* Rover: 4.0.0, 4.1.0

## LICENSE
This work is distributed under the GNU GPLv3 license.
