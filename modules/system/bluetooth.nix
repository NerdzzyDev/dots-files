{
  hardware.bluetooth = {
    enable = true;

    settings = {
      General = {
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;
}


#{
#  hardware.bluetooth.enable = true;
#  services.blueman.enable = true;
#}
