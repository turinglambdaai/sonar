# Sonar

**Racket 内存向量检索——分块、嵌入、存储、召回。**

[![CI](https://github.com/turinglambdaai/sonar/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/sonar/actions/workflows/ci.yml) ![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**[English](README.md) · 中文**

Sonar 在内存中维护一份已嵌入的文本语料，只回答一个问题：*哪些段落与这条查询最相似？* 文本按句界分块，经你控制的 embedder 生成向量，入库时归一化一次，检索就是一个普通点积。纯核心不碰网络——嵌入边界是一个参数，接 [Switchboard](https://github.com/turinglambdaai/switchboard) 适配层只需一次显式 require。

Sonar 不是数据库、磁盘索引或 agent 框架。它只拥有中间那一块最容易在临时脚本里做错的部分：确定性分块、响亮的失败，以及一条库不变式——每个嵌入向量都是单位向量。

## 快速开始

```racket
(require sonar)

;; 1. 选定 embedder。核心在配置前直接报错。
(require sonar/switchboard)
(current-batch-embed switchboard-batch-embed)

;; 2. 建库。
(define store (make-store #:name "notes"))
(store-add-document!
 store
 (file->string "notes/climate.txt")
 #:source "climate.txt")

;; 3. 检索。
(for ([hit (in-list (store-search store "how fast do glaciers move?"))])
  (printf "~a  ~a...\n"
          (entry-source (cdr hit))
          (substring (entry-text (cdr hit)) 0 60)))
```

离线运行完全不需要 provider——注入任意批量 embedder 即可：

```racket
(parameterize ([current-batch-embed my-embedder])
  (store-search store "query"))
```

`examples/semantic-search.rkt` 是一个可运行的完整走查，CI 里用确定性玩具 embedder 离线执行。

## 设计要点

- **嵌入边界即参数。** `current-batch-embed` 是向量进库的唯一入口。未配置的 embedder 直接抛错——不存在隐式 provider，漏掉的配置步骤不可能悄悄掏空你的检索质量。
- **归一化一次。** 每个嵌入在入库时归一化；检索是每条目一个点积，分数是可比的 `[-1, 1]` 余弦值。
- **保证前进。** 分块器在附近有句界时句界断开，否则硬切，且对任意输入保证扫描前进——病态文本无法让它死循环。
- **失败响亮。** 维度不匹配、零向量、损坏的库文件、返回数量不对的 embedder，全部以 `exn:fail:sonar` 抛出并指明原因。
- **嵌入缓存是包装器而非隐含行为。** `make-cached-batch-embedder` 包装任意批量函数，重读语料不会为已知文本重复付费。

## 开发

```sh
raco pkg install --auto --name sonar .
raco test -p sonar
raco setup --check-pkg-deps sonar
racket examples/semantic-search.rkt
```

CI 在 Linux、Windows、macOS 三平台 × Racket 9.0 / 9.3 上跑测试，并做依赖声明检查、参考手册构建与离线走查。

## 许可证

[Apache-2.0](LICENSE)
