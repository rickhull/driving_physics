module DrivingPhysics
  def self.elapsed_display(elapsed_ms)
    elapsed_s = elapsed_ms / 1000
    h = elapsed_s / 3600
    elapsed_s -= h * 3600
    m = elapsed_s / 60
    s = elapsed_s % 60
    ms = elapsed_ms % 1000

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end
end
