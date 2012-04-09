window.addEventListener("load", eventWindowLoaded, false);

function eventWindowLoaded ()
{
	canvasApp();
}

function canvasApp ()
{
    var depth = 200;
    var escape2 = 400;

    var color_map = 
	    [ [ 0.0, 0.0, 0.5 ] ,
	      [ 0.0, 0.0, 1.0 ] ,
	      [ 0.0, 0.5, 1.0 ] ,
	      [ 0.0, 1.0, 1.0 ] ,
	      [ 0.5, 1.0, 0.5 ] ,
	      [ 1.0, 1.0, 0.0 ] ,
	      [ 1.0, 0.5, 0.0 ] ,
	      [ 1.0, 0.0, 0.0 ] ,
	      [ 0.5, 0.0, 0.0 ] ,
	      [ 0.5, 0.0, 0.0 ] ,
	      [ 1.0, 0.0, 0.0 ] ,
	      [ 1.0, 0.5, 0.0 ] ,
	      [ 1.0, 1.0, 0.0 ] ,
	      [ 0.5, 1.0, 0.5 ] ,
	      [ 0.0, 1.0, 1.0 ] ,
	      [ 0.0, 0.5, 1.0 ] ,
	      [ 0.0, 0.0, 1.0 ] ,
	      [ 0.0, 0.0, 0.5 ] ,
	      [ 0.0, 0.0, 0.0 ] ];

	var canvas = document.getElementById("mandelbrotview");
	var ctx = canvas.getContext("2d"); 

	function mag2(real, imag) { return real*real + imag*imag; }

    function mandel(x, y)
    {
        var z0_r = 3 * (x/canvas.width) - 2;
        var z0_i = 3 * (y/canvas.height) - 1.5;

	    var z_r = 0;
	    var z_i = 0;
	    var k = 0;
	    for(; k <= depth && mag2(z_r, z_i) < escape2 ; ++k) {
	    	var t_r = z_r; var t_i = z_i;
	    	z_r = t_r * t_r - t_i * t_i + z0_r;
	    	z_i = 2 * t_r * t_i + z0_i;
	    }
        return Math.log(k + 1.0 - Math.log(Math.log(Math.max(mag2(z_r, z_i), escape2)) / 2.0) / Math.log(2.0));
    }

    function interpolate(d, v0, v1)
    {
        var result =
            [ d * (v1[0] - v0[0]) + v0[0],
              d * (v1[1] - v0[1]) + v0[1], 
              d * (v1[2] - v0[2]) + v0[2] ];
        return result;
    }

  	function paint()
    {
        var data = ctx.createImageData(canvas.width, canvas.height); 
        
        var begin = (new Date()).getTime();

        for (var x = 0; x < data.width; x++)
        {
            for (var y = 0; y < data.height; y++)
            {
                var log_count = mandel(x, y);
                var idx = (x + y * canvas.width) * 4;
                var min_result = 1;
                var max_result = Math.log(depth);
                var stops = 18.0;

                var v = (log_count - min_result) / (max_result - min_result) * stops;
                var bin = Math.max(0, Math.floor(v));

                if(bin >= stops)
                {
                    data.data[idx + 0] = 0;
                    data.data[idx + 1] = 0;
                    data.data[idx + 2] = 0;
                    data.data[idx + 3] = 255;
                }
                else
                {
                    var rgb0 = color_map[bin];
                    var rgb1 = color_map[bin+1];
                    var d = v - bin;
                    var rgb =  interpolate(d, rgb0, rgb1);
                    data.data[idx + 0] = rgb[0] * 255;
                    data.data[idx + 1] = rgb[1] * 255;
                    data.data[idx + 2] = rgb[2] * 255;
                    data.data[idx + 3] = 255;
                }                
            }
        }

        var elapsed = ((new Date()).getTime() - begin).toString(10);
        ctx.putImageData(data, 0, 0);

        ctx.fillStyle = "#ffffff";
		ctx.font = "12px monospace";
		ctx.textBaseline = "top";
		ctx.fillText(elapsed+" milliseconds", 10, 10 );
	}

	paint();
}
