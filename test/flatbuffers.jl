# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

const FB = Arrow.FlatBuffers

# A table with a vector of Int32, a byte vector and a string
struct TestFields <: FB.Table
    bytes::Vector{UInt8}
    pos::Base.Int
end

function Base.getproperty(x::TestFields, field::Symbol)
    if field === :numbers
        o = FB.offset(x, 4)
        o != 0 && return FB.Array{Int32}(x, o)
    elseif field === :data
        o = FB.offset(x, 6)
        o != 0 && return FB.bytevector(x, o + FB.pos(x))
    elseif field === :name
        o = FB.offset(x, 8)
        o != 0 && return String(x, o + FB.pos(x))
    end
    return nothing
end

function testfields(b::FB.Builder; numbers=Int32[1, 2, 3], data=UInt8[4, 5], name="six")
    numbers = FB.createvector!(b, numbers)
    data = FB.createbytevector(b, data)
    name = FB.createstring!(b, name)
    FB.startobject!(b, 3)
    FB.prependoffsetslot!(b, 0, numbers, 0)
    FB.prependoffsetslot!(b, 1, data, 0)
    FB.prependoffsetslot!(b, 2, name, 0)
    FB.finish!(b, FB.endobject!(b))
    return collect(FB.finishedbytes(b))
end

@testset "FlatBuffers" begin
    bytes = testfields(FB.Builder())
    t = FB.getrootas(TestFields, bytes, 0)
    @test t.numbers == Int32[1, 2, 3]
    @test t.data == UInt8[4, 5]
    @test t.name == "six"

    # A reset builder builds the same bytes again, in the buffer of a larger table before
    b = FB.Builder()
    testfields(b; numbers=Int32[7, 8, 9, 10], name="seventeen")
    n = length(FB.bytes(b))
    FB.reset!(b)
    @test testfields(b) == bytes
    @test length(FB.bytes(b)) == n

    # The vectors are built last, so they end up at the end of the buffer.
    # Cutting it short puts the last number beyond the end.
    t = FB.getrootas(TestFields, bytes[1:(end - 4)], 0)
    @test_throws BoundsError t.numbers
    @test_throws BoundsError FB.getrootas(TestFields, bytes[1:2], 0)
end
