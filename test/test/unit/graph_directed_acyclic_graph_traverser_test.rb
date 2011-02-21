require 'test_helper'

class GraphDirectedAcyclicGraphTraverserTest < ActiveSupport::TestCase
  def setup
    Authorize::Redis::String.index.clear # Clear the cache
    Authorize::Redis::Set.index.clear
    Authorize::Redis::Hash.index.clear
    Authorize::Graph::DirectedAcyclicGraph.index.clear
    Authorize::Graph::Vertex.index.clear
    Authorize::Graph::Edge.index.clear
  end

  test 'traverse DAG' do
    g0 = Authorize::Graph::DirectedAcyclicGraph.new
    v0 = g0.vertex("Charlottesville")
    v1 = g0.vertex("Richmond")
    v2 = g0.vertex("Springfield")
    v3 = g0.vertex("Dunn_Loring")
    v4 = g0.vertex("Centreville")
    v5 = g0.vertex("Strasburg")
    v6 = g0.vertex("Staunton")
    e0 = g0.edge(nil, v0, v1, :name => "I64", :cost => 100)
    e1 = g0.edge(nil, v1, v2, :name => "I95", :cost => 85)
    e2 = g0.edge(nil, v2, v3, :name => "I495", :cost => 20)
    e3 = g0.edge(nil, v3, v4, :name => "I66", :cost => 40)
    e4 = g0.edge(nil, v4, v5, :name => "I66", :cost => 120)
    e5 = g0.edge(nil, v5, v6, :name => "I81", :cost => 130)
    assert_equal Set[v2, v5, v6], g0.traverse(v0).select{|v| /S.*/.match(v.id)}.to_set
  end

  test 'traverse DAG from vertex' do
    g0 = Authorize::Graph::DirectedAcyclicGraph.new("Interstates")
    v0 = g0.vertex("Charlottesville")
    v1 = g0.vertex("Richmond")
    v2 = g0.vertex("Springfield")
    v3 = g0.vertex("Dunn_Loring")
    v4 = g0.vertex("Centreville")
    v5 = g0.vertex("Strasburg")
    v6 = g0.vertex("Staunton")
    e0 = g0.edge(nil, v0, v1, :name => "I64", :cost => 100)
    e1 = g0.edge(nil, v1, v2, :name => "I95", :cost => 85)
    e2 = g0.edge(nil, v2, v3, :name => "I495", :cost => 20)
    e3 = g0.edge(nil, v3, v4, :name => "I66", :cost => 40)
    e4 = g0.edge(nil, v4, v5, :name => "I66", :cost => 120)
    e5 = g0.edge(nil, v5, v6, :name => "I81", :cost => 130)
    assert_equal Set[v3, v4, v5, v6], g0.traverse(v3).to_set
  end

  test 'traverse cyclic DAG with checking' do
    g0 = Authorize::Graph::DirectedAcyclicGraph.new("Interstates")
    v0 = g0.vertex("Charlottesville")
    v1 = g0.vertex("Richmond")
    e0a = g0.edge(nil, v0, v1, :name => "I64", :cost => 100)
    e0b = g0.edge(nil, v1, v0, :name => "I64", :cost => 100)
    assert_raises RuntimeError do
      g0.traverse(v0, true).to_set
    end
  end
end