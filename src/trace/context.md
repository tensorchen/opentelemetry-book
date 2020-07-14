# Trace Context

本文是[Trace Context Level 2 W3C Editor's Draft 30 June 2020](https://w3c.github.io/trace-context/)的中文翻译。

本规范定义了标准的HTTP头部和其值的格式，用于在分布式追踪场景下传播上下文信息。该规范标准化了如何在服务之间发送和修改上下文信息。上下文信息唯一地标识分布式系统中的各个请求，并且还定义了一种添加和传播特定于提供商的上下文信息的方法。

## 2.概述

### 2.1 问题陈述

分布式追踪是一个方法论，它被追踪工具实现用于跟踪，分析和调试跨多个软件组件的事务。通常，分布式追踪将经过一个以上组件，这要求它在所有参与系统中都是唯一可识别的。跟踪上下文传播沿着此唯一标识传递。如今，跟踪上下文的传播是由每个跟踪系统单独实现的。在多跟踪系统环境中，这会导致互操作性问题，例如：

- 由于没有共享的唯一标识符，因此无法关联由不同跟踪系统收集的跟踪。
- 跨越不同跟踪系统之间的边界的跟踪无法传播，因为没有要转发的一致同意的标识集。
- 中间商可能会丢弃跟踪系统特定的元数据。
- 云平台系统，中间件和服务提供商不能保证支持跟踪上下文传播，因为没有标准可以去遵循。

过去，这些问题并未产生重大影响，因为大多数应用程序都由单个跟踪系统进行监视，并且始终处于单个平台提供商的范围之内。如今，越来越多的应用程序高度分散，并利用了多种中间件服务和云平台。

现代应用程序的这种转换要求分布式跟踪上下文传播标准的建立。

### 2.2 解决

跟踪上下文规范定义了一种通用的格式，用于交换跟踪上下文传播数据（称为跟踪上下文）。跟踪上下文通过以下方式解决了上述问题。


- 为单个跟踪和请求提供唯一的标识符，从而允许将多个提供程序的跟踪数据链接在一起。
- 提供一种商定的机制来转发特定于跟踪系统的跟踪数据，避免因多个跟踪工具参与一个事务而导致的跟踪中断。
- 提供中间件，平台和硬件提供商可以支持的行业标准。

统一的跟踪数据传播方法可以提高对分布式应用程序行为的可见性，从而促进问题和性能分析。跟踪上下文提供的互操作性是管理基于现代微服务的应用程序的先决条件。

### 2.3 设计概述

跟踪上下文分为两个单独的传播字段，分别支持互操作性和特定于跟踪系统的可扩展性：

- `traceparent` 以可移植的固定长度格式描述传入请求在其跟踪图中的位置。它的设计侧重于快速解析。每个跟踪工具必须正确的设置`traceparent`。
- `tracestate` 由一组名称/值对表示的特定于跟踪系统的数据。在`tracestate`存储信息是可选的。

跟踪工具可以提供两个级别的与跟踪上下文交互的兼容行为：

- 它们至少必须传播traceparent和tracestate标头，并确保跟踪不中断。此行为也称为转发跟踪。
- 此外，他们还可以通过修改traceparent标头和tracestate包含其专有信息的标头的相关部分来选择参与跟踪。这也称为参与跟踪。

## 3. HTTP请求标头格式

本节描述了分布式跟踪上下文traceparent与tracestateHTTP标头的格式。

### 3.1 标头关系

`traceparent` 请求header表示在分布式追踪系统中进入的请求，它具有共同的格式，所有的跟踪系统均应该理解。traceparent示例:

    traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01

    tracestate: congo=t61rcWkgMzE

例如：假设系统中的客户端和服务器使用不同的跟踪系统：Congo 和 Rojo。在Congo系统中跟踪的客户端将以下标头添加到出站HTTP请求中。

    traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
    tracestate: congo=t61rcWkgMzE

**注意**：在这种情况下，该tracestate值t61rcWkgMzE是Base64对父ID（b7ad6b7169203331）进行编码的结果，尽管不需要此类操作。

在Rojo跟踪系统中跟踪的接收服务器将继续接收tracestate它，并在左侧添加一个新条目。

    traceparent: 00-0af7651916cd43dd8448eb211c80319c-00f067aa0ba902b7-01
    tracestate: rojo=00f067aa0ba902b7,congo=t61rcWkgMzE

您会注意到，Rojo系统将其值重用于其traceparent在中的条目tracestate。这意味着它是一个通用的跟踪系统（不传递专有信息）。否则，tracestate条目是不透明的，并且可能是特定于跟踪系统的。

如果下一个接收服务器使用 Congo，它将继承tracestate Rojo的身份，并在上一个条目的左侧添加一个新的父条目。

    traceparent: 00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01
    tracestate: congo=ucfJifl5GOE,rojo=00f067aa0ba902b7

**注意**： ucfJifl5GOE是Base64编码的父ID b9c7c989f97918e1。

请注意，Congo 在编写traceparent条目时并未对其进行编码，这有助于进行关联的人员保持一致。但是，其条目的值tracestate经过编码，与有所不同traceparent。

最后，您会看到tracestate Rojo的条目保持原样，只是向右推。最左侧的位置让下一台服务器知道与哪个跟踪系统相对应traceparent。在这种情况下，由于 Congo 写过traceparent，它的tracestate条目应该在最左边。    

### 3.2 Traceparent Header 

`traceparent` HTTP标头字段标识的跟踪系统传入的请求。它具有四个字段：

- version
- trace-id
- parent-id
- trace-flags

#### 3.2.1 Header名称

Header名称: `traceparent`

为了增加在多个协议的互操作性和成功整合，在默认情况下的跟踪系统应该保持头名小写。标头名称是一个没有任何分隔符的单词，例如连字符（`-`）。

跟踪系统必须假设header名称可能有各种格式（大写，小写，混合），并应该使用小写发送header名称。

#### 3.2.2 Header属性值

本部分使用[RFC5234](https://tools.ietf.org/html/rfc5234) 的增强Backus-Naur格式（ABNF）表示法，包括该文档中的DIGIT规则。该DIGIT规则定义一个数字字符0- 9。

    HEXDIGLC = DIGIT / "a" / "b" / "c" / "d" / "e" / "f" ; 小写16进制字符
    value           = version "-" version-format

破折号（-）用作字段之间的分隔符。

##### 3.2.2.1 version

    version         = 2HEXDIGLC   ; 本文档假设version是00，version ff是被禁止的。

该值是US-ASCII编码的（符合UTF-8）。

版本（version）是1个字节，代表8位无符号整数。版本ff无效。当前规范假定将version设置为00。

##### 3.2.2.2 version-format

以下version-format用于定义version 00的格式。

    version-format   = trace-id "-" parent-id "-" trace-flags
    trace-id         = 32HEXDIGLC  ; 16字节ID。全0是被禁止的。
    parent-id        = 16HEXDIGLC  ; 8字节ID。全0是被禁止的。
    trace-flags      = 2HEXDIGLC   ; 8位标志。当前, 只有一位被使用。

##### 3.2.2.3 trace-id

这是整个跟踪森林的ID，用于唯一标识通过系统的分布式追踪。它表示为一个16字节数组，例如 4bf92f3577b34da6a3ce929d0e0e4736。所有零（00000000000000000000000000000000）字节被视为无效值。

如果该trace-id值无效（例如，如果该值包含不允许的字符或全零），则跟踪系统必须忽略traceparent。

##### 3.2.2.4 parent-id

这是调用方所知道的此请求的ID（在某些跟踪系统中，这称为span-id，这个span是客户端请求的执行操作）。它表示为8字节数组，例如00f067aa0ba902b7。所有零（0000000000000000）字节被视为无效值。

如果该parent-id值无效（例如，包含非小写16进制字符），则跟踪系统必须忽略traceparent。

##### 3.2.2.5 trace-flags

一个8bit字段，用于控制跟踪标志（例如采样，跟踪级别等）。这些标志是调用方给出的建议，而不是需要严格遵循的规则，有如下三个原因：

1. 不受信任的调用方可能会通过恶意设置这些标志来滥用跟踪系统。
2. 调用方可能本身有BUG从而导致跟踪系统异常。
3. 主调服务和被调服务之间不同的负载情况，可能会迫使被调方降低采样率。

像其他字段一样，trace-flags也是十六进制编码的。例如，所有8个标志均被设置的值是`ff`，没有标志被设置的值是`00`。

###### 3.2.2.5.1 Sampled flag

本规范的当前版本(00)仅支持一个称为的标志sampled。

设置时，最低有效位（最右边）表示主调方可能已记录了跟踪数据。取消设置时，主调方未记录带外跟踪数据。

有许多可能会破坏分布式跟踪的记录情况：

- 仅记录请求的子集会导致跟踪中断。
- 在加载时，记录有关所有传入和传出请求的信息变得非常昂贵。
- 做出随机或特定于组件的数据收集决策会导致所有跟踪中的数据碎片化。

由于存在这些问题，跟踪系统会自行制定记录决策，因此，对于该工作的最佳算法没有共识。

各种技术包括：

- 概率采样（通过掷硬币来采样100条分布式迹线中的1条）
- 延迟的决定（根据持续时间或请求结果做出收集决定）
- 延期采样（让被叫方决定是否需要收集有关此请求的信息）

如何实施这些技术可以跟踪特定于跟踪系统或应用程序定义。

该tracestate领域旨在处理各种技术，以制定特定于给定跟踪系统的记录决策（或其他特定信息）。该sampled标志提供了跟踪系统之间更好的互操作性。它使跟踪系统可以交流记录决策并为客户提供更好的体验。

例如，当SaaS服务参与分布式跟踪时，该服务不知道其调用者使用的跟踪系统。该服务可能会生成传入请求的记录，以进行监视或故障排除。该sampled标志可用于确保有关被标记为由呼叫者记录的请求的信息也将被下游的SaaS服务记录，以便呼叫者可以对每个记录的请求的行为进行故障排除。

该sampled标志对其更改没有任何限制，除了只能在更新parent-id时才对其进行更改。

以下是跟踪系统应该用来提高跟踪系统互操作性的一组建议：

- 如果一个组件明确作出了是否进行记录的决定，这个决定应该反映在`sampled`标志位中。
- 如果一个组件需要作出是否记录的决定，应该遵守`sampled`标志位的值。应考虑安全因素，以防止滥用或恶意使用此标志。
- 如果某个组件推迟或延迟了决策，并且仅记录了遥测的一个子集，则该sampled标志应保持不变。0由该组件启动跟踪时，应将其设置为默认选项。

跟踪系统可以遵循两个附加选项：

- 做出延迟或延迟记录决定的组件可以通过将请求的子集设置sampled为1来传达记录的优先级。
- 组件也可能会退回到概率采样，并将sampled标志设置1为请求子集。

###### 3.2.2.5.2 Other Flags

其它标志行为 例如(00000100) 是没有被定义，为未来所预留的。跟踪系统必须将这些设置为0。

#### 3.2.3 HTTP traceparent Headers 示例

调用者对该请求进行采样时有效的traceparent：

    Value = 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
    base16(version) = 00
    base16(trace-id) = 4bf92f3577b34da6a3ce929d0e0e4736
    base16(parent-id) = 00f067aa0ba902b7
    base16(trace-flags) = 01  // sampled

调用者未对此请求进行采样时有效的traceparent：

    Value = 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00
    base16(version) = 00
    base16(trace-id) = 4bf92f3577b34da6a3ce929d0e0e4736
    base16(parent-id) = 00f067aa0ba902b7
    base16(trace-flags) = 00  // not sampled


#### 3.2.4 Traceparent版本

跟踪系统解析traceparent必须遵循如下规则，以应对可能出现的各种异常格式：

- 仅作为传递的服务不需要解析，只能考虑禁止过大headers。
- 当version前缀解析不正确时（它不是2个16进制字符后接破折号（-）），实现中应该重新进行跟踪。
- 如果检测到更高版本，则实现应通过尝试以下操作尝试对其进行解析：
  - 如果标头的大小小于55个字符，则跟踪系统不应解析标头，而应重新进行跟踪。
  - 解析trace-id（从第一个破折号到接下来的32个字符）。跟踪系统必须检查32个字符是否为十六进制，并其后存在破折号（-）。
  - 解析parent-id（从第35个位置的第二个破折号到接下来的16个字符）。跟踪系统必须检查16个字符是否为十六进制，后接破折号。
  - 解析sampled的位flags（从第三破折号2个字符）。跟踪系统必须检查两个字符是否在字符串末尾或后跟破折号。
  如果成功解析了所有三个值，则跟踪系统应使用它们。

跟踪系统不得对此版本解析或假设有关未知字段的任何内容。跟踪系统必须traceparent根据实现已知的规范的最高版本（在此规范中为00）使用这些字段来构造新字段。

### 3.3 Tracestate Header

TODO

### 3.4 改变 traceparent 字段

收到traceparent请求标头的跟踪系统必须将其发送到外发请求。它可以在将此标头的值传递给传出请求之前先对其进行改变。

如果值traceparent字段传播之前没有改变，那么 tracestate 也必须不被修改。未经修改的标头传播通常在代理之类的直通服务中实现。此行为也可以在当前不收集分布式跟踪信息的服务中实现。

以下是允许的更改列表：

- 更新 parent-id: 此值可以被设置为代表当前操作ID的新值。这是最典型的改变，应该设置为默认行为。
- 更新 sampled: 
- 重新跟踪(restart trace)：
- 降级版本:  

跟踪系统绝不能对traceparent进行非上述改变。

### 3.5 改变 tracestate 字段

## 4. HTTP响应Header格式

本节描述了分布式跟踪上下文到traceresponseHTTP标头的格式。

### 4.1 Traceresponse Header

traceresponseHTTP响应报头字段标识在追踪系统中的完成的请求。它具有四个字段：

- version
- trace-id
- proposed-parent-id
- trace-flags

#### 4.1.1 Header名称

标头名称： traceresponse

为了增加跨多个协议的互操作性并鼓励成功的集成，标头名称应小写。标头名称是一个没有任何分隔符的单词，例如连字符（-）。

跟踪系统必须在任何情况下都希望标题名称（大写，小写，混合），并且应该以小写形式发送标题名称。

#### 4.1.2 Header属性值

本部分使用[RFC5234](https://tools.ietf.org/html/rfc5234) 的增强Backus-Naur格式（ABNF）表示法，包括该文档中的DIGIT规则。该DIGIT规则定义一个数字字符0- 9。

    HEXDIGLC = DIGIT / "a" / "b" / "c" / "d" / "e" / "f" ; 小写16进制字符
    value           = version "-" version-format

破折号（-）用作字段之间的分隔符。

##### 4.1.2.1 version 

    version         = 2HEXDIGLC   ; this document assumes version 00. Version 255 is forbidden

该值是US-ASCII编码的（符合UTF-8）。

版本（version）是1个字节，代表8位无符号整数。版本255无效。当前规范假定将version设置为00。

##### 4.1.2.2 version-format

以下version-format定义用于version 00。

    version-format   = [trace-id] "-" [proposed-parent-id] "-" [trace-flags]
    trace-id         = 32HEXDIGLC  ; 16 bytes array identifier. All zeroes forbidden
    proposed-parent-id        = 16HEXDIGLC  ; 8 bytes array identifier. All zeroes forbidden
    trace-flags      = 2HEXDIGLC   ; 8 bit flags. Currently, only one bit is used. See below for details

##### 4.1.2.3 trace-id

这是整个跟踪林的ID，用于唯一地标识通过系统的分布式跟踪。它表示为一个16字节的数组，例如4bf92f3577b34da6a3ce929d0e0e4736。所有零（00000000000000000000000000000000）字节均被视为无效值。

如果该trace-id值无效（例如，如果该值包含不允许的字符或全零），则跟踪系统必须忽略traceresponse。

该trace-id字段是traceresponse响应头的可选部分。如果请求头中包含一个有效的traceparent一个trace-id，并且被叫方不使用不同trace-id，被调用方应该从traceparent中忽略trace-id字段。


##### 4.1.2.4 proposed-parent-id

这是被调用方所知道的调用请求的ID（在某些跟踪系统中，这称为span-id，其中span是客户端请求的执行）。它表示为8字节数组，例如00f067aa0ba902b7。所有零（0000000000000000）字节均被视为无效值。

跟踪系统必须忽略traceresponse，当proposed-parent-id 无效时（例如，如果包含非小写的十六进制字符）。

该proposed-parent-id字段是traceresponse响应头的可选部分。如果请求标头包含一个有效的traceparent带有parent-id的字符，被调用方应该省略proposed-parent-id字段traceresponse。

##### 4.1.2.5 trace-flags

### 4.2 返回traceresponse字段

跟踪系统可以在任何响应中添加`traceresponse`，无论请求中是否包含`traceparent`。

以下是建议的用例：

#### 4.2.1 重新跟踪

当请求越过信任边界时，被叫服务可以决定重新启动跟踪。在这种情况下，被叫服务可以返回一个traceresponse指示其内部trace-id和采样决定的字段。

请求和响应示例：

请求

    traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-d75597dee50b0cac-01

响应

    traceresponse: 00-1baad25c36c11c1e7fbd6d122bd85db6--01

在此示例中，具有ID的跟踪的参与者4bf92f3577b34da6a3ce929d0e0e4736调用第三方系统，该第三方系统使用新的跟踪ID收集自己的内部遥测1baad25c36c11c1e7fbd6d122bd85db6。当第三方完成其请求时，它将新的跟踪ID和内部采样决策返回给调用方。如果请求有错误，则主调方可以在支持请求中包含第三方的内部跟踪ID。

**注意**：在这种情况下，proposed-parent-id从响应中省略了，因为作为其他跟踪的一部分，对于调用者来说是没有必要获取的。

#### 4.2.2 负载均衡器

当请求通过负载均衡器时，负载均衡器可能希望将采样决策推迟到其被叫服务。在这种情况下，被叫服务可以返回一个traceresponse指示其采样决定的字段。

请求和响应示例：

请求

    traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-d75597dee50b0cac-00

响应

    traceresponse: 00---01

在此示例中，具有ID的跟踪中的调用方（负载均衡器）4bf92f3577b34da6a3ce929d0e0e4736希望将采样决策推迟到其被调用方。被呼叫者完成请求后，会将内部采样决策返回给呼叫者。

**注意**：在这种情况下，响应中均省略proposed-parent-id和trace-id。因为跟踪没有重新启动，并且调用方仅请求采样决定，所以proposed-parent-id和trace-id均未更改。

#### 4.2.3 Web Browser

如果Web浏览器加载web页面不支持提供trace上下文时，加载初始页面时将不包含任何trace上下文的头部。在这种情况下，服务器可以返回一个traceresponse字段，供在浏览器中作为脚本运行的跟踪工具使用。

响应示例：

    traceresponse: 00-4bf92f3577b34da6a3ce929d0e0e4736-d75597dee50b0cac-01

在此示例中，服务器告诉浏览器它应为当前操作采用跟踪ID 4bf92f3577b34da6a3ce929d0e0e4736和父ID d75597dee50b0cac。

#### 4.2.4 尾部采样

当做出否定采样决定的服务调用另一个服务时，在该请求的处理过程中可能会发生一些事件，导致被叫服务决定对请求进行采样。在这种情况下，它可以将其更新的采样决策返回给呼叫者，呼叫者还可以将更新的采样决策返回给其呼叫者，依此类推。这样，即使原始采样决定是否定的，也可以为调试目的恢复尽可能多的迹线。

请求和响应示例：

请求

    traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-d75597dee50b0cac-00

响应

    traceresponse: 00---01

## 5. 处理模型

本章节非规范性质。

本节提供了一个跟踪跟踪系统的分步示例，该跟踪系统接收带有跟踪上下文标头的请求，处理该请求，然后可能转发该请求。在实施符合跟踪上下文的跟踪系统，中间件（例如代理或消息传递总线）或云服务时，此描述可用作参考。

### 5.1 跟踪上下文的处理模型

## 6. 其它通讯协议

尽管为HTTP定义了跟踪上下文，但作者承认它也与其他通信协议有关。该规范的扩展以及外部组织产生的规范定义了其他协议的跟踪上下文序列化和反序列化的格式。请注意，这些扩展的成熟度可能与此规范不同。

有关其他协议的跟踪上下文实现的详细信息，请参考[trace-context-protocols-registry](https://www.w3.org/TR/trace-context-protocols-registry/) 。

## 7. 隐私注意事项

将标头传播到下游服务以及存储这些标头的值的要求带来了潜在的隐私问题。跟踪系统绝不能使用traceparent和tracestate字段来获取任何可个人识别或其他敏感信息。这些字段的唯一目的是启用跟踪关联。

跟踪系统必须评估滥用标头的风险。本节提供一些注意事项，并对与存储和传播这些标头有关的风险进行了初步评估。跟踪系统可能选择检查并从字段中删除敏感信息，然后再允许跟踪系统执行可能传播或存储这些字段的代码。但是，所有更改都应符合本规范中定义的可更改列表。


