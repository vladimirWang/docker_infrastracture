-- 启用 pgvector 扩展
-- 此脚本由 postgres 官方镜像启动时自动执行（仅数据卷为空、首次初始化时跑一次）
-- 后续重启不会重复执行，但 CREATE EXTENSION IF NOT EXISTS 本身也是幂等的
CREATE EXTENSION IF NOT EXISTS vector;
