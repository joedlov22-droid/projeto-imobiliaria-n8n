-- 1. Habilitar a extensão de vetores
create extension if not exists vector;

-- 2. Criar a tabela de documentos (certifique-se de usar UUID se for o seu caso)
create table if not exists condominios (
  id uuid primary key default gen_random_uuid(),
  content text,
  metadata jsonb,
  embedding vector(1536) -- 1536 é o padrão para modelos OpenAI
);

-- 3. Criar um índice para buscas mais rápidas (opcional, mas recomendado)
create index on condominios using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

-- 4. Função de busca semântica (RPC)
-- Removemos a versão anterior para evitar conflitos
drop function if exists match_documents;

-- Criamos a função para busca vetorial com suporte a filtros
create or replace function match_documents (
  query_embedding vector(1536),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id uuid,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    condominios.id,
    condominios.content,
    condominios.metadata,
    1 - (condominios.embedding <=> query_embedding) as similarity
  from condominios
  where condominios.metadata @> filter
  order by condominios.embedding <=> query_embedding
  limit match_count;
end;
$$;
