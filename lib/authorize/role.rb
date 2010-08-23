require 'authorize/redis'

class Authorize::Role < ActiveRecord::Base
  set_table_name 'authorize_roles'
  belongs_to :_resource, :polymorphic => true, :foreign_type => 'resource_type', :foreign_key => 'resource_id'
  has_many :permissions, :class_name => "Authorize::Permission", :dependent => :delete_all
  validates_uniqueness_of :name, :scope => [:resource_type, :resource_id]
  after_save :create_vertex
  # TODO: after_destroy to delete vertex and associated edges

  # This exists to simplify finding and creating global and class-level roles.  For resource instance-related
  # roles, use the standard Rails association (#roles) created for authorizable resources.
  named_scope :for, lambda {|resource|
    resource_conditions = if (resource == Object) then
       {:resource_id => nil, :resource_type => nil}
    elsif resource.is_a?(Class) then
       {:resource_id => nil, :resource_type => resource.to_s}
    else
       {:resource_id => resource.id, :resource_type => resource.class.to_s}
    end
    {:conditions => resource_conditions}
  }
  named_scope :global, :conditions => {:resource_type => nil, :resource_id => nil}
  named_scope :identity, :conditions => {:name => nil}

  def self.graph
    @graph ||= Authorize::Graph.load('Authorize::Role::graph')
  end

  def create_vertex
    self.class.graph.vertex("Authorize::Role::vertices::#{id}")
  end

  # Virtual attribute that expands the common belongs_to association with a three-level hierarchy
  # OPTIMIZE: revert this to a standard belongs_to association -do we really need the hierarchy here?
  def resource
    return Object unless resource_type
    return resource_type.constantize unless resource_id
    return _resource
  end
  alias identity resource

  def resource=(res)
    return self._resource = res unless res.kind_of?(Class)
    self.resource_id = nil
    return self[:resource_type] = nil if res == Object
    return self[:resource_type] = res.to_s
  end
  alias identity= resource

  def nymous?
    _resource.nil?
  end

  # Link from this role's vertex to other's vertex in the system role graph.  This role becomes the parent.
  def link(other)
    self.class.graph.edge(nil, vertex, other.vertex)
  end

  # Creates or updates the unique permission for a given resource to have the given modes
  # Example:  public.may(:list, :read, widget)
  def may(*args)
    p = permissions.for(args.pop).find_or_initialize_by_role_id(id) # need a #find_or_initialize_by_already_specified_scope
    p.mask += Authorize::Permission::Mask[*args]
    p.save
    p.mask.complete
  end

  # Updates or deletes the unique permission for a given resource to not have the given modes
  # Example:  public.may_not(:update, widget)
  def may_not(*args)
    p = permissions.for(args.pop).first
    return Authorize::Permission::Mask[] unless p
    p.mask -= Authorize::Permission::Mask[*args].complete
    p.mask.empty? ? p.destroy : p.save
    p.mask.complete
  end

  # Test if all given modes are permitted for the given resource
  def may?(*args)
    return false unless p = permissions.for(args.pop).first
    mask = Authorize::Permission::Mask[*args].complete
    mask.subset?(p.mask)
  end

  # Test if none of the given modes are permitted for the given resource
  def may_not?(*args)
    return true unless p = permissions.for(args.pop).first
    mask = Authorize::Permission::Mask[*args].complete
    (mask & p.mask).empty?
  end

  def to_s
    (name || "%s") % resource rescue "!! INVALID ROLE NAME !!"
  end

  def vertex
    raise 'Not possible to dereference vertex for an unpersisted role' unless id
    @vertex ||= Authorize::Graph::Vertex.load("Authorize::Role::vertices::#{id}")
  end

  def roles
    ids = vertex.traverse.map{|v| v.id.slice(/.*::(\d+)/, 1) }
    self.class.find(ids).to_set
  end

  def children
    roles.delete(self)
  end

  def parents
    raise "Not Yet Implemented"
  end
end