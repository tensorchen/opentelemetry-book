# Log：词汇

本文档定义了在OpenTelemetry中使用的日志的词汇表。

### Log Record

事件的记录。通常，记录包含指示事件发生时间的时间戳以及描述发生的事件，发生的位置等的其他数据。

也被称为 Log Entry。

### Log

有时用于表示`Log Record`日志记录的集合。这里是比较容易混淆的，因为人们经常使用`Log`代表单条`Log Record`。因此应该谨慎使用此术语，并在可能出现歧义的情况下使用其它限定词（例如`Log Record`）。

### Embedded Log

嵌入式日志。`Log Records`嵌入在 `Span`对象的事件列表中。

### Standalone Log

独立日志。`Log Records`没有被嵌入到`Span`中，而是被记录在其它位置。

### Log Attributes

日志属性。`Log Record` 中包含的键/值对。

### Structured Logs

结构化日志。以具有明确定义的结构的格式记录的日志，该结构允许区分日志记录的不同元素（例如，时间戳，属性等）。

### Flat File Logs

记录在文本文件中的日志，通常每个日志记录一行（尽管也可以使用多行记录）。
