defmodule ForkWithFlags.Dev.EctoRepo.Migrations.EnsureColumnsAreNotNull do
  use Ecto.Migration
  #
  # Use this migration to add the `not null` constraints to the
  # table created using the `CreateFeatureFlagsTable` migration
  # from versions `<= 1.0.0`.
  #
  # If the table has been created with a migration from `>= 1.1.0`,
  # then the `not null` constraints are already there and there
  # is no need to run this migration. In that case, this migration
  # is a no-op.
  #
  # This migration assumes the default table name of "fun_with_flags_toggles"
  # is being used. If you have overridden that via configuration, you should
  # change this migration accordingly.

  def up do
    IO.inspect(System.get_env("RDBMS"), label: "HULLO")

    if System.get_env("RDBMS") == "sqlite" do
      # we must drop the index before we replace the columns for sqlite3 compat
      drop(
        index(
          :fun_with_flags_toggles,
          [:flag_name, :gate_type, :target],
          unique: true,
          name: "fwf_flag_name_gate_target_idx"
        )
      )

      alter table(:fun_with_flags_toggles) do
        # modify would be better, but we do it this way for sqlite3 compat
        remove(:flag_name)
        add(:flag_name, :string, null: false)

        remove(:gate_type)
        add(:gate_type, :string, null: false)

        remove(:target)
        add(:target, :string, null: false)

        remove(:enabled)
        add(:enabled, :boolean, null: false)
      end

      # re-create index
      create(
        index(
          :fun_with_flags_toggles,
          [:flag_name, :gate_type, :target],
          unique: true,
          name: "fwf_flag_name_gate_target_idx"
        )
      )
    else
      alter table(:fun_with_flags_toggles) do
        modify(:flag_name, :string, null: false)
        modify(:gate_type, :string, null: false)
        modify(:target, :string, null: false)
        modify(:enabled, :boolean, null: false)
      end
    end
  end

  def down do
    if System.get_env("RDBMS") == "sqlite" do
      drop(
        index(
          :fun_with_flags_toggles,
          [:flag_name, :gate_type, :target],
          unique: true,
          name: "fwf_flag_name_gate_target_idx"
        )
      )

      alter table(:fun_with_flags_toggles) do
        # modify would be better, but we do it this way for sqlite3 compat
        remove(:flag_name)
        add(:flag_name, :string, null: true)

        remove(:gate_type)
        add(:gate_type, :string, null: true)

        remove(:target)
        add(:target, :string, null: true)

        remove(:enabled)
        add(:enabled, :boolean, null: true)
      end

      create(
        index(
          :fun_with_flags_toggles,
          [:flag_name, :gate_type, :target],
          unique: true,
          name: "fwf_flag_name_gate_target_idx"
        )
      )
    else
      alter table(:fun_with_flags_toggles) do
        modify(:flag_name, :string, null: true)
        modify(:gate_type, :string, null: true)
        modify(:target, :string, null: true)
        modify(:enabled, :boolean, null: true)
      end
    end
  end
end
