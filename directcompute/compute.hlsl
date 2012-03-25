RWTexture2D<float4> Output;

const int N;
const int depth;
const int escape2;

float2 trans_xy(float2 xy, int N)
{
    const float2 offset = float2(2.0, 1.5);
    return (xy / N) * 3.0 - offset;
}

float mag2(float2 ri)
{
    return ri.x*ri.x + ri.y*ri.y;
}

static const float3 color_map[] =
    { float3( 0.0, 0.0, 0.5 ) ,
      float3( 0.0, 0.0, 1.0 ) ,
      float3( 0.0, 0.5, 1.0 ) ,
      float3( 0.0, 1.0, 1.0 ) ,
      float3( 0.5, 1.0, 0.5 ) ,
      float3( 1.0, 1.0, 0.0 ) ,
      float3( 1.0, 0.5, 0.0 ) ,
      float3( 1.0, 0.0, 0.0 ) ,
      float3( 0.5, 0.0, 0.0 ) ,
      float3( 0.5, 0.0, 0.0 ) ,
      float3( 1.0, 0.0, 0.0 ) ,
      float3( 1.0, 0.5, 0.0 ) ,
      float3( 1.0, 1.0, 0.0 ) ,
      float3( 0.5, 1.0, 0.5 ) ,
      float3( 0.0, 1.0, 1.0 ) ,
      float3( 0.0, 0.5, 1.0 ) ,
      float3( 0.0, 0.0, 1.0 ) ,
      float3( 0.0, 0.0, 0.5 ) ,
      float3( 0.0, 0.0, 0.0 ) };

const static int stops = 18;

float3 interpolate(const float3 d, const float3 v0, const float3 v1)
{
    return d * (v1 - v0) + v0;
}

float3 map_to_argb(float x)
{
    const static float min_result = 1;
    const static float max_result = log(depth);
    x = (x - min_result) / (max_result - min_result) * stops;
    int bin = (int) x;
    if(bin >= stops)
        return float3(0,0,0);
    else
    {
        const float3 rgb0 = color_map[bin];
        const float3 rgb1 = color_map[bin+1];
        float d = x - bin;
        return interpolate(d, rgb0, rgb1);
    }
}

[numthreads(20, 20, 1)]
void main( uint3 threadID : SV_DispatchThreadID )
{
    float2 z0 = trans_xy(threadID.xy, N);
    float2 z = float2(0, 0);
    int k = 0;
    for(; k < depth && mag2(z) < escape2; ++k)
    {
        float2 t = z;
        z = float2(t.x*t.x - t.y*t.y + z0.x, 2*t.x*t.y+z0.y);
    }
    float log_count = log(k + 1.0 - log(log(max(mag2(z), escape2)) / 2.0) / log(2.0));
    float3 rgba = map_to_argb(log_count);
    Output[threadID.xy] = float4(rgba.z, rgba.y, rgba.x, 1);
}
