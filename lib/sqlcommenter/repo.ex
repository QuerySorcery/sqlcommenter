defmodule Sqlcommenter.Repo do
  @type t :: module

  @spec all_running() :: [atom() | pid()]
  defdelegate all_running(), to: Ecto.Repo.Registry

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {otp_app, adapter, behaviours} =
        Ecto.Repo.Supervisor.compile_config(__MODULE__, opts)

      @otp_app otp_app
      @adapter adapter
      @default_dynamic_repo opts[:default_dynamic_repo] || __MODULE__
      @read_only opts[:read_only] || false
      @before_compile adapter
      @aggregates [:count, :avg, :max, :min, :sum]
      @sqlcommenter opts[:sqlcommenter] || []

      def config do
        {:ok, config} = Ecto.Repo.Supervisor.init_config(:runtime, __MODULE__, @otp_app, [])
        config
      end

      def __adapter__ do
        @adapter
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Ecto.Repo.Supervisor.start_link(__MODULE__, @otp_app, @adapter, opts)
      end

      def stop(timeout \\ 5000) do
        Supervisor.stop(get_dynamic_repo(), :normal, timeout)
      end

      def load(schema_or_types, data) do
        Ecto.Repo.Schema.load(@adapter, schema_or_types, data)
      end

      def checkout(fun, opts \\ []) when is_function(fun) do
        %{adapter: adapter} = meta = Ecto.Repo.Registry.lookup(get_dynamic_repo())
        adapter.checkout(meta, opts, fun)
      end

      def checked_out? do
        %{adapter: adapter} = meta = Ecto.Repo.Registry.lookup(get_dynamic_repo())
        adapter.checked_out?(meta)
      end

      @compile {:inline, get_dynamic_repo: 0}

      def get_dynamic_repo() do
        Process.get({__MODULE__, :dynamic_repo}, @default_dynamic_repo)
      end

      def put_dynamic_repo(dynamic) when is_atom(dynamic) or is_pid(dynamic) do
        Process.put({__MODULE__, :dynamic_repo}, dynamic) || @default_dynamic_repo
      end

      def default_options(_operation), do: []
      defoverridable default_options: 1

      defp prepare_opts(operation_name, opts, caller) do
        comment = get_comment(caller)

        operation_name
        |> default_options()
        |> Keyword.merge(opts)
        |> Keyword.merge(comment)
      end

      defp get_comment(caller) do
        [
          comment:
            Sqlcommenter.Commenter.to_str(
              @sqlcommenter ++
                [module: caller.module, function: caller.function, line: caller.line]
            )
        ]
      end

      ## Transactions
      if Ecto.Adapter.Transaction in behaviours do
        defmacro transaction(fun_or_multi, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:transaction, opts, __CALLER__)

          quote do
            Ecto.Repo.Transaction.transaction(
              __MODULE__,
              unquote(repo),
              unquote(fun_or_multi),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        # in_transaction? and rollback don't need to be macros since they don't use prepare_opts
        def in_transaction?, do: Ecto.Repo.Transaction.in_transaction?(get_dynamic_repo())
        def rollback(value), do: Ecto.Repo.Transaction.rollback(get_dynamic_repo(), value)
      end

      ## Schemas
      if Ecto.Adapter.Schema in behaviours and not @read_only do
        defmacro insert(struct, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:insert, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.insert(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro update(struct, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:update, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.update(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro insert_or_update(changeset, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:insert_or_update, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.insert_or_update(
              __MODULE__,
              unquote(repo),
              unquote(changeset),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro delete(struct, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:delete, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.delete(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro insert!(struct, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:insert, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.insert!(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro update!(struct, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:update, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.update!(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro insert_or_update!(changeset, opts \\ []) do
          repo = get_dynamic_repo()

          opts = prepare_opts(:insert_or_update, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.insert_or_update!(
              __MODULE__,
              unquote(repo),
              unquote(changeset),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro delete!(struct, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:delete, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.delete!(
              __MODULE__,
              unquote(repo),
              unquote(struct),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro insert_all(schema_or_source, entries, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:insert_all, opts, __CALLER__)

          quote do
            Ecto.Repo.Schema.insert_all(
              __MODULE__,
              unquote(repo),
              unquote(schema_or_source),
              unquote(entries),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end
      end

      ## Queryable
      if Ecto.Adapter.Queryable in behaviours do
        if not @read_only do
          defmacro update_all(queryable, updates, opts \\ []) do
            repo = get_dynamic_repo()
            opts = prepare_opts(:update_all, opts, __CALLER__)

            quote do
              Ecto.Repo.Queryable.update_all(
                unquote(repo),
                unquote(queryable),
                unquote(updates),
                Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
              )
            end
          end

          defmacro delete_all(queryable, opts \\ []) do
            repo = get_dynamic_repo()
            opts = prepare_opts(:delete_all, opts, __CALLER__)

            quote do
              Ecto.Repo.Queryable.delete_all(
                unquote(repo),
                unquote(queryable),
                Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
              )
            end
          end
        end

        defmacro all(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.all(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro stream(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:stream, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.stream(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro get(queryable, id, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.get(
              unquote(repo),
              unquote(queryable),
              unquote(id),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro get!(queryable, id, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.get!(
              unquote(repo),
              unquote(queryable),
              unquote(id),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro get_by(queryable, clauses, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.get_by(
              unquote(repo),
              unquote(queryable),
              unquote(clauses),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro get_by!(queryable, clauses, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.get_by!(
              unquote(repo),
              unquote(queryable),
              unquote(clauses),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro reload(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:reload, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.reload(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro reload!(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:reload, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.reload!(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro one(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.one(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro one!(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.one!(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro exists?(queryable, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.exists?(
              unquote(repo),
              unquote(queryable),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        defmacro preload(struct_or_structs_or_nil, preloads, opts \\ []) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:preload, opts, __CALLER__)

          quote do
            Ecto.Repo.Preloader.preload(
              unquote(struct_or_structs_or_nil),
              unquote(repo),
              unquote(preloads),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        # Aggregate functions need special handling due to their multiple clauses
        defmacro aggregate(queryable, aggregate, field_or_opts \\ []) do
          repo = get_dynamic_repo()

          opts =
            case {aggregate, field_or_opts} do
              {:count, opts} when is_list(opts) -> prepare_opts(:all, opts, __CALLER__)
              _ -> prepare_opts(:all, [], __CALLER__)
            end

          quote do
            case {unquote(aggregate), unquote(field_or_opts)} do
              {agg, opts} when agg in [:count] and is_list(opts) ->
                Ecto.Repo.Queryable.aggregate(
                  unquote(repo),
                  unquote(queryable),
                  agg,
                  Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
                )

              {agg, field} when agg in @aggregates and is_atom(field) ->
                Ecto.Repo.Queryable.aggregate(
                  unquote(repo),
                  unquote(queryable),
                  agg,
                  field,
                  Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
                )
            end
          end
        end

        defmacro aggregate(queryable, aggregate, field, opts) do
          repo = get_dynamic_repo()
          opts = prepare_opts(:all, opts, __CALLER__)

          quote do
            Ecto.Repo.Queryable.aggregate(
              unquote(repo),
              unquote(queryable),
              unquote(aggregate),
              unquote(field),
              Ecto.Repo.Supervisor.tuplet(unquote(repo), unquote(opts))
            )
          end
        end

        def prepare_query(operation, query, opts), do: {query, opts}
        defoverridable prepare_query: 3
      end
    end
  end
end
