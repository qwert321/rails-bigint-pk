require 'active_support/all'
require 'bigint_pk/version'

module BigintPk
  mattr_accessor :enabled

  autoload :Generators, 'generators/bigint_pk'

  def self.setup
    yield self
  end

  def self.enabled= value
    install_patches! if value
  end

  private

  def self.install_patches!
    install_primary_key_patches!
    install_foreign_key_patches!
  end

  def self.install_primary_key_patches!
    ActiveRecord::Base.establish_connection
    ca = ActiveRecord::ConnectionAdapters

    if ca.const_defined? :PostgreSQLAdapter
      ca::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:primary_key] = 'bigserial primary key'
    end

    if ca.const_defined? :AbstractMysqlAdapter
      ca::AbstractMysqlAdapter::NATIVE_DATABASE_TYPES[:primary_key] = 'bigint(20) DEFAULT NULL auto_increment PRIMARY KEY'
      ca::AbstractMysqlAdapter::NATIVE_DATABASE_TYPES[:integer] = { :name => "bigint", :limit => 6 }
    end
  end

  def self.install_foreign_key_patches!
    [   ActiveRecord::ConnectionAdapters::TableDefinition,
        ActiveRecord::ConnectionAdapters::Table].each do |abstract_table_type|

      abstract_table_type.class_eval do
        def references_with_default_bigint_fk *args
          options = args.extract_options!
          options.reverse_merge! limit: 8
          # Limit shouldn't affect "#{col}_type" column in polymorphic reference.
          # But don't change value if it isn't simple 'true'.
          # Examples:
          #   t.references :subject, null: false, polymorphic: true ==> t.integer :subject_id, limit: 8, null: false
          #                                                             t.string  :subject_type, null: false
          #   t.references :subject, polymorphic: { limit: 120 }    ==> t.integer :subject_id, limit: 8
          #                                                             t.string  :subject_type, limit: 120
          options[:polymorphic] = options.except(:polymorphic, :limit) if options[:polymorphic] == true 
          references_without_default_bigint_fk( *args, options )
        end
        alias_method_chain :references, :default_bigint_fk
      end
    end
  end
end
