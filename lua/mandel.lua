N = 1000
depth = 200
escape2 = 400
color_map = {
   { 0.0, 0.0, 0.5 } ,
   { 0.0, 0.0, 1.0 } ,
   { 0.0, 0.5, 1.0 } ,
   { 0.0, 1.0, 1.0 } ,
   { 0.5, 1.0, 0.5 } ,
   { 1.0, 1.0, 0.0 } ,
   { 1.0, 0.5, 0.0 } ,
   { 1.0, 0.0, 0.0 } ,
   { 0.5, 0.0, 0.0 } ,
   { 0.5, 0.0, 0.0 } ,
   { 1.0, 0.0, 0.0 } ,
   { 1.0, 0.5, 0.0 } ,
   { 1.0, 1.0, 0.0 } ,
   { 0.5, 1.0, 0.5 } ,
   { 0.0, 1.0, 1.0 } ,
   { 0.0, 0.5, 1.0 } ,
   { 0.0, 0.0, 1.0 } ,
   { 0.0, 0.0, 0.5 } ,
   { 0.0, 0.0, 0.0 } }

function mag2(real, imag)
   return real*real + imag*imag
end

function mandel(x, y)
   local z0_r = 3 * (x/N) - 2
   local z0_i = 3 * (y/N) - 1.5
   local z_r = 0
   local z_i = 0
   local k = 0
   while k <= depth and mag2(z_r, z_i) < escape2 do
	  local t_r = z_r
	  local t_i = z_i
	  z_r = t_r * t_r - t_i * t_i + z0_r
	  z_i = 2 * t_r * t_i + z0_i
	  k = k+1
   end
   return math.log(k + 1.0 - math.log(math.log(math.max(mag2(z_r, z_i), escape2)) / 2.0) / math.log(2.0));
end

function interpolate(d, v0, v1)
   return { d * (v1[1] - v0[1]) + v0[1],
			d * (v1[2] - v0[2]) + v0[2], 
			d * (v1[3] - v0[3]) + v0[3] }
end

bitmap = {}
local start = os.clock()
for y = 0, N-1 do
   for x = 0, N-1 do
	  local log_count = mandel(x, y);
	  local idx = (x + y * N) * 4;
	  local min_result = 1;
	  local max_result = math.log(depth);
	  local stops = 19;
	  local v = (log_count - min_result) / (max_result - min_result) * stops;
	  local bin = math.max(0, math.floor(v))+ 1;
	  if (bin >= stops) then
		 bitmap[y*N+x] = {0,0,0}
	  else
		 local rgb0 = color_map[bin];
		 local rgb1 = color_map[bin+1];
		 local d = v+1-bin;
		 local rgb = interpolate(d, rgb0, rgb1);
		 bitmap[y*N+x] = {rgb[1] * 255,
						  rgb[2] * 255,
						  rgb[3] * 255}
	  end
   end
end
print(string.format('%2fms', (os.clock() - start)*1000))

file = io.open('mandel.ppm', 'w')
file:write(string.format([[P3
%d %d
255
]], N, N))
for _,pixel in pairs(bitmap) do
   file:write(string.format('%d,%d,%d,', pixel[1],pixel[2],pixel[3]))
end
file:close()
